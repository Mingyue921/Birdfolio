import { createServer } from 'node:http';
import { setDefaultResultOrder } from 'node:dns';
import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDatabase } from './database.mjs';
import { searchGbifBirds } from './gbif.mjs';
import { bearerToken, createAuthStore, LEGACY_USER_ID } from './auth.mjs';
import { body, errorStatus, json, rawBody, requestId, required } from './http.mjs';
import { createLogger } from './logger.mjs';
import { scheduleMediaCleanup } from './media-cleanup.mjs';
import { handleAuthRoutes } from './routes/auth-routes.mjs';
import { handleCommunityRoutes } from './routes/community-routes.mjs';
import { handleMediaRoutes } from './routes/media-routes.mjs';
import { handleAiRoutes } from './routes/ai-routes.mjs';
import { createObservationService, handleObservationRoutes, timestampMilliseconds } from './routes/observation-routes.mjs';

setDefaultResultOrder('ipv4first');
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));

function loadEnv(path) {
  if (!existsSync(path)) return {};
  return Object.fromEntries(readFileSync(path, 'utf8').split(/\r?\n/).filter(line => line && !line.startsWith('#')).map(line => {
    const index = line.indexOf('='); return index < 0 ? [line.trim(), ''] : [line.slice(0, index).trim(), line.slice(index + 1).trim()];
  }));
}

function assertProductionConfig(env, host) {
  if (String(env.NODE_ENV || '').toLowerCase() !== 'production') return;
  const problems = [];
  if (String(env.REQUIRE_AUTH || '').toLowerCase() !== 'true') problems.push('REQUIRE_AUTH=true');
  const cors = String(env.CORS_ORIGIN || '').trim();
  if (!cors || cors === '*') problems.push('CORS_ORIGIN allow-list');
  if (host === '0.0.0.0' || host === '::') problems.push('HOST must be loopback behind HTTPS proxy');
  const visionUrl = String(env.VISION_API_URL || '').trim();
  if (!visionUrl || !String(env.VISION_API_KEY || '').trim() || !String(env.VISION_MODEL || '').trim()) problems.push('VISION_API_URL/VISION_API_KEY/VISION_MODEL');
  else { try { if (new URL(visionUrl).protocol !== 'https:') problems.push('VISION_API_URL=https'); } catch { problems.push('VISION_API_URL'); } }
  const mailUrl = String(env.MAIL_PROVIDER_URL || '').trim();
  if (!mailUrl) problems.push('MAIL_PROVIDER_URL');
  else { try { if (new URL(mailUrl).protocol !== 'https:') problems.push('MAIL_PROVIDER_URL=https'); } catch { problems.push('MAIL_PROVIDER_URL'); } }
  if (problems.length > 0) throw new Error('PRODUCTION_CONFIG_INVALID: ' + problems.join(', '));
}

export function createBirdfolioServer(options = {}) {
  const dataDir = resolve(options.dataDir || join(root, 'data')); mkdirSync(dataDir, { recursive: true });
  const env = { ...loadEnv(join(root, '.env')), ...process.env, ...(options.env || {}) };
  const logger = options.logger || createLogger(options.logOutput || console);
  const seedDemo = String(env.DEMO_MODE ?? 'true').toLowerCase() !== 'false';
  const db = openDatabase(options.databasePath || join(dataDir, 'birdfolio.db'), { seed: seedDemo, logger });
  const auth = createAuthStore(db, { env });
  const requireAuthByDefault = String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'production';
  const speciesCatalog = options.speciesCatalog || (input => searchGbifBirds({ ...input, cachePath: join(dataDir, 'gbif-cache.json') }));
  const rateBuckets = new Map();
  const observations = createObservationService(db, required);

  function enforceRate(key, limit, windowMs) {
    const now = Date.now(); const current = rateBuckets.get(key);
    if (!current || current.startedAt + windowMs <= now) { rateBuckets.set(key, { startedAt: now, count: 1 }); return; }
    current.count += 1; if (current.count > limit) throw new Error('RATE_LIMITED');
  }

  function actor(req, input = {}, requiredAuth = requireAuthByDefault) {
    const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null;
    if (presented && !user) throw new Error('INVALID_TOKEN');
    if (requiredAuth && !user) throw new Error('AUTH_REQUIRED');
    const legacyAllowed = String(env.ALLOW_LEGACY_DEMO ?? (String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' ? 'false' : 'true')).toLowerCase() !== 'false';
    if (!user && !legacyAllowed) throw new Error('AUTH_REQUIRED');
    return { user, userId: user?.id || String(input.userId || LEGACY_USER_ID), authenticated: Boolean(user) };
  }

  const handlers = [handleAuthRoutes, handleCommunityRoutes, handleObservationRoutes, handleMediaRoutes, handleAiRoutes];
  const server = createServer(async (req, res) => {
    const started = Date.now(); const url = new URL(req.url, 'http://localhost'); const rid = requestId(req);
    res.once('finish', () => logger.info('http.request_completed', { requestId: rid, method: req.method, path: url.pathname, status: res.statusCode, elapsedMs: Date.now() - started }));
    if (req.method === 'OPTIONS') {
      res.writeHead(204, { 'access-control-allow-origin': String(env.CORS_ORIGIN || '*'), 'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS', 'access-control-allow-headers': 'content-type,authorization,idempotency-key,x-request-id' }); res.end(); return;
    }
    const context = { req, res, url, env, rid, db, auth, actor, body, rawBody, json, required, enforceRate, dataDir, requireAuthByDefault, observationRows: observations.rows, writeObservation: observations.write };
    try {
      if (req.method === 'GET' && url.pathname === '/api/health') { json(res, 200, { ok: true, service: 'birdfolio', aiMode: env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim() ? 'provider' : 'unavailable', auth: 'email_code', version: 'beta-1' }, env, rid); return; }
      if (req.method === 'GET' && url.pathname === '/api/species') { const query = url.searchParams.get('q') || ''; const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); json(res, 200, await speciesCatalog({ query, limit }), env, rid); return; }
      for (const handler of handlers) { if (await handler(context)) return; }
      json(res, 404, { error: 'NOT_FOUND' }, env, rid);
    } catch (error) {
      const message = String(error?.message || error);
      logger.error('http.request_failed', { requestId: rid, method: req.method, path: url.pathname, error: message });
      json(res, errorStatus(message), { error: message, requestId: rid }, env, rid);
    }
  });

  const stopCleanup = scheduleMediaCleanup(db, { intervalMs: Number(env.MEDIA_CLEANUP_INTERVAL_MS || 15 * 60 * 1000), logger });
  server.on('close', () => { stopCleanup(); db.close(); });
  return server;
}

export { timestampMilliseconds };

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const env = { ...loadEnv(join(root, '.env')), ...process.env };
  const port = Number(env.PORT || 8787);
  const production = process.argv.includes('--release') || String(env.NODE_ENV || '').toLowerCase() === 'production';
  if (production) env.NODE_ENV = 'production';
  const host = env.HOST || (production ? '127.0.0.1' : '0.0.0.0');
  assertProductionConfig(env, host);
  const logger = createLogger();
  createBirdfolioServer({ env, logger }).listen(port, host, () => logger.info('server.started', { host, port }));
}
