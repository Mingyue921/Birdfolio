import { createServer } from 'node:http';
import { setDefaultResultOrder } from 'node:dns';
import { mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createAuthStore } from './auth.mjs';
import { databasePath, loadEnv, serverRoot } from './config.mjs';
import { openDatabase } from './database.mjs';
import { searchGbifBirds } from './gbif.mjs';
import { body, errorCategory, errorStatus, handleCorsPreflight, json, rawBody, requestId, required, routeTemplate } from './http.mjs';
import { createLogger } from './logger.mjs';
import { scheduleMediaCleanup } from './media-cleanup.mjs';
import { createActor } from './middleware/auth.mjs';
import { handleAccountRoutes } from './routes/account-routes.mjs';
import { handleAuthRoutes } from './routes/auth-routes.mjs';
import { handleCommunityRoutes } from './routes/community-routes.mjs';
import { handleIdentificationRoutes } from './routes/identification-routes.mjs';
import { handleMediaRoutes } from './routes/media-routes.mjs';
import { createObservationService, handleObservationRoutes, timestampMilliseconds } from './routes/observation-routes.mjs';
import { handleSyncRoutes } from './routes/sync-routes.mjs';

setDefaultResultOrder('ipv4first');

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
  const dataDir = resolve(options.dataDir || join(serverRoot, 'data')); mkdirSync(dataDir, { recursive: true });
  const env = loadEnv(options.env || {}); const logger = options.logger || createLogger(options.logOutput || console);
  const production = String(env.NODE_ENV || '').toLowerCase() === 'production';
  const seedDemo = String(env.DEMO_MODE ?? (production ? 'false' : 'true')).toLowerCase() !== 'false';
  const openDatabaseImpl = options.openDatabaseImpl || openDatabase;
  const db = openDatabaseImpl(options.databasePath || databasePath(env, dataDir), { seed: seedDemo, logger });
  let stopCleanup = () => {};
  let resourcesClosed = false;

  function closeResources() {
    if (resourcesClosed) return;
    resourcesClosed = true;
    try { stopCleanup(); } catch { /* continue closing the database */ }
    try { db.close(); } catch { /* lifecycle cleanup is best effort and idempotent */ }
  }

  try {
    const auth = (options.createAuthStoreImpl || createAuthStore)(db, { env });
    const requireAuthByDefault = String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'production';
    const speciesCatalog = options.speciesCatalog || (input => searchGbifBirds({ ...input, cachePath: join(dataDir, 'gbif-cache.json') }));
    const observations = (options.createObservationServiceImpl || createObservationService)(db, required);
    const actor = createActor({ auth, env, requireAuthByDefault }); const rateBuckets = new Map();
    function enforceRate(key, limit, windowMs) { const now = Date.now(); const current = rateBuckets.get(key); if (!current || current.startedAt + windowMs <= now) { rateBuckets.set(key, { startedAt: now, count: 1 }); return; } current.count += 1; if (current.count > limit) throw new Error('RATE_LIMITED'); }

    const handlers = options.routeHandlers || [handleAuthRoutes, handleAccountRoutes, handleCommunityRoutes, handleObservationRoutes, handleSyncRoutes, handleMediaRoutes, handleIdentificationRoutes];
    const server = createServer(async (req, res) => {
      const started = Date.now(); const url = new URL(req.url, 'http://localhost'); const rid = requestId(req); const route = routeTemplate(url.pathname);
      let failureCategory = '';
      res.once('finish', () => {
        const status = res.statusCode;
        logger.info('http.request_completed', { requestId: rid, method: req.method, route, status, elapsedMs: Date.now() - started, errorCategory: failureCategory || (status >= 400 ? errorCategory('', status) : '') });
      });
      if (handleCorsPreflight(req, res, env, rid)) return;
      const context = { req, res, url, env, rid, db, auth, actor, body, rawBody, json, required, enforceRate, dataDir, requireAuthByDefault, observationRows: observations.rows, writeObservation: observations.write };
      try {
        if (req.method === 'GET' && url.pathname === '/api/health') { json(res, 200, { ok: true, service: 'birdfolio', aiMode: env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim() ? 'provider' : 'unavailable', auth: 'email_code', version: 'beta-1' }, env, rid); return; }
        if (req.method === 'GET' && url.pathname === '/api/species') { const query = url.searchParams.get('q') || ''; const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); json(res, 200, await speciesCatalog({ query, limit }), env, rid); return; }
        for (const handler of handlers) { if (await handler(context)) return; }
        json(res, 404, { error: 'NOT_FOUND' }, env, rid);
      } catch (error) {
        const message = String(error?.message || error); const status = errorStatus(message); failureCategory = errorCategory(message, status);
        json(res, status, { error: message, requestId: rid }, env, rid);
      }
    });

    stopCleanup = (options.scheduleMediaCleanupImpl || scheduleMediaCleanup)(db, { intervalMs: Number(env.MEDIA_CLEANUP_INTERVAL_MS || 15 * 60 * 1000), logger });
    const nativeClose = server.close.bind(server); let closeStarted = false;
    server.once('close', closeResources);
    server.close = callback => {
      if (closeStarted || resourcesClosed) { queueMicrotask(() => callback?.()); return server; }
      closeStarted = true;
      try {
        nativeClose(error => { closeResources(); callback?.(error?.code === 'ERR_SERVER_NOT_RUNNING' ? undefined : error); });
      } catch (error) {
        closeResources(); queueMicrotask(() => callback?.(error?.code === 'ERR_SERVER_NOT_RUNNING' ? undefined : error));
      }
      return server;
    };
    return server;
  } catch (error) {
    closeResources();
    throw error;
  }
}

export { timestampMilliseconds };

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const env = loadEnv(); const port = Number(env.PORT || 8787);
  const production = process.argv.includes('--release') || String(env.NODE_ENV || '').toLowerCase() === 'production';
  if (production) env.NODE_ENV = 'production';
  const host = env.HOST || (production ? '127.0.0.1' : '0.0.0.0'); assertProductionConfig(env, host);
  const logger = createLogger(); createBirdfolioServer({ env, logger }).listen(port, host, () => logger.info('server.started', { host, port }));
}
