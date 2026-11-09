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
import { createMailProvider } from './platform/mail-provider.mjs';
import { createPersistentRateLimiter } from './platform/rate-limiter.mjs';
import { openPostgresDatabase } from './platform/postgres.mjs';
import { migratePostgres } from './platform/postgres-migrations.mjs';
import { createLocalMediaStorage, createMediaStorage } from './platform/media-storage.mjs';

setDefaultResultOrder('ipv4first');

function assertProductionConfig(env, host) {
  if (String(env.NODE_ENV || '').toLowerCase() !== 'production') return;
  const problems = [];
  if (String(env.REQUIRE_AUTH || '').toLowerCase() !== 'true') problems.push('REQUIRE_AUTH=true');
  const cors = String(env.CORS_ORIGIN || '').trim();
  if (!cors || cors === '*') problems.push('CORS_ORIGIN allow-list');
  if ((host === '0.0.0.0' || host === '::') && String(env.HTTPS_PROXY || '').toLowerCase() !== 'true') problems.push('HTTPS_PROXY=true is required for a container listener');
  if (String(env.DATABASE_PROVIDER || '').toLowerCase() !== 'postgres' || !String(env.DATABASE_URL || '').trim()) problems.push('DATABASE_PROVIDER=postgres and DATABASE_URL');
  if (String(env.DATABASE_SSL || 'true').toLowerCase() !== 'true') problems.push('DATABASE_SSL=true');
  if (String(env.MEDIA_STORAGE || '').toLowerCase() !== 'obs') problems.push('MEDIA_STORAGE=obs');
  for (const key of ['OBS_ENDPOINT', 'OBS_BUCKET', 'OBS_ACCESS_KEY_ID', 'OBS_SECRET_ACCESS_KEY']) if (!String(env[key] || '').trim()) problems.push(key);
  const visionUrl = String(env.VISION_API_URL || '').trim();
  if (!visionUrl || !String(env.VISION_API_KEY || '').trim() || !String(env.VISION_MODEL || '').trim()) problems.push('VISION_API_URL/VISION_API_KEY/VISION_MODEL');
  else { try { if (new URL(visionUrl).protocol !== 'https:') problems.push('VISION_API_URL=https'); } catch { problems.push('VISION_API_URL'); } }
  const mailUrl = String(env.MAIL_PROVIDER_URL || '').trim();
  if (!mailUrl) problems.push('MAIL_PROVIDER_URL');
  else { try { if (new URL(mailUrl).protocol !== 'https:') problems.push('MAIL_PROVIDER_URL=https'); } catch { problems.push('MAIL_PROVIDER_URL'); } }
  if (!String(env.MAIL_PROVIDER_TOKEN || '').trim()) problems.push('MAIL_PROVIDER_TOKEN');
  if (String(env.AUTH_DEBUG_CODES || '').toLowerCase() === 'true' || String(env.AUTH_DEV_CODE || '').trim()) problems.push('debug auth codes disabled');
  if (String(env.DEMO_MODE || '').toLowerCase() !== 'false') problems.push('DEMO_MODE=false');
  if (problems.length > 0) throw new Error('PRODUCTION_CONFIG_INVALID: ' + problems.join(', '));
}

export function createBirdfolioServer(options = {}) {
  const dataDir = resolve(options.dataDir || join(serverRoot, 'data')); mkdirSync(dataDir, { recursive: true });
  const env = loadEnv(options.env || {}); const logger = options.logger || createLogger(options.logOutput || console);
  const production = String(env.NODE_ENV || '').toLowerCase() === 'production';
  const seedDemo = String(env.DEMO_MODE ?? (production ? 'false' : 'true')).toLowerCase() !== 'false';
  const openDatabaseImpl = options.openDatabaseImpl || openDatabase;
  const databaseProvider = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase();
  if (!options.db && databaseProvider === 'postgres') throw new Error('USE_ASYNC_SERVER_FACTORY');
  const db = options.db || openDatabaseImpl(options.databasePath || databasePath(env, dataDir), { seed: seedDemo, logger });
  let stopCleanup = () => {};
  let closePromise = null;
  let managedMediaStorage = options.mediaStorage;

  function closeResources() {
    if (closePromise) return closePromise;
    const pending = [];
    try { stopCleanup(); } catch { /* continue closing dependencies */ }
    try { const result = managedMediaStorage?.close?.(); if (result?.then) pending.push(result); } catch { /* continue closing database */ }
    try { const result = db.close(); if (result?.then) pending.push(result); } catch { /* lifecycle cleanup is best effort and idempotent */ }
    closePromise = Promise.allSettled(pending).then(() => undefined);
    return closePromise;
  }

  try {
    const auth = (options.createAuthStoreImpl || createAuthStore)(db, { env });
    const requireAuthByDefault = String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'production';
    const speciesCatalog = options.speciesCatalog || (input => searchGbifBirds({ ...input, cachePath: join(dataDir, 'gbif-cache.json') }));
    const observations = (options.createObservationServiceImpl || createObservationService)(db, required, env);
    const actor = createActor({ auth, env, requireAuthByDefault });
    const enforceRate = options.enforceRate || createPersistentRateLimiter(db);
    const mailProvider = options.mailProvider || createMailProvider(env);
    const mediaStorage = managedMediaStorage || createLocalMediaStorage(dataDir); managedMediaStorage = mediaStorage;

    const handlers = options.routeHandlers || [handleAuthRoutes, handleAccountRoutes, handleCommunityRoutes, handleObservationRoutes, handleSyncRoutes, handleMediaRoutes, handleIdentificationRoutes];
    const server = createServer(async (req, res) => {
      const started = Date.now(); const url = new URL(req.url, 'http://localhost'); const rid = requestId(req); const route = routeTemplate(url.pathname);
      let failureCategory = '';
      res.once('finish', () => {
        const status = res.statusCode;
        logger.info('http.request_completed', { requestId: rid, method: req.method, route, status, elapsedMs: Date.now() - started, errorCategory: failureCategory || (status >= 400 ? errorCategory('', status) : '') });
      });
      if (handleCorsPreflight(req, res, env, rid)) return;
      const context = { req, res, url, env, rid, db, auth, actor, body, rawBody, json, required, enforceRate, mailProvider, mediaStorage, dataDir, requireAuthByDefault, observationRows: observations.rows, writeObservation: observations.write };
      try {
        if (req.method === 'GET' && url.pathname === '/health/live') { json(res, 200, { ok: true, service: 'birdfolio' }, env, rid); return; }
        if (req.method === 'GET' && url.pathname === '/health/ready') { try { await db.health?.(); await mediaStorage.health?.(); json(res, 200, { ok: true, database: databaseProvider, storage: mediaStorage.kind }, env, rid); } catch { json(res, 503, { ok: false, error: 'DEPENDENCY_UNAVAILABLE' }, env, rid); } return; }
        if (req.method === 'GET' && url.pathname === '/api/health') { json(res, 200, { ok: true, service: 'birdfolio', aiMode: env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim() ? 'provider' : 'unavailable', auth: 'email_code', version: 'beta-1' }, env, rid); return; }
        if (req.method === 'GET' && url.pathname === '/api/species') { const query = url.searchParams.get('q') || ''; const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); json(res, 200, await speciesCatalog({ query, limit }), env, rid); return; }
        for (const handler of handlers) { if (await handler(context)) return; }
        json(res, 404, { error: 'NOT_FOUND' }, env, rid);
      } catch (error) {
        const message = String(error?.message || error); const status = errorStatus(message); failureCategory = errorCategory(message, status);
        json(res, status, { error: message, requestId: rid }, env, rid);
      }
    });

    stopCleanup = (options.scheduleMediaCleanupImpl || scheduleMediaCleanup)(db, { intervalMs: Number(env.MEDIA_CLEANUP_INTERVAL_MS || 15 * 60 * 1000), logger, storage: mediaStorage });
    const nativeClose = server.close.bind(server); let closeStarted = false;
    server.close = callback => {
      if (closeStarted || closePromise) { Promise.resolve(closeResources()).then(() => callback?.()); return server; }
      closeStarted = true;
      try {
        nativeClose(error => { Promise.resolve(closeResources()).then(() => callback?.(error?.code === 'ERR_SERVER_NOT_RUNNING' ? undefined : error)); });
      } catch (error) {
        Promise.resolve(closeResources()).then(() => callback?.(error?.code === 'ERR_SERVER_NOT_RUNNING' ? undefined : error));
      }
      return server;
    };
    return server;
  } catch (error) {
    void closeResources();
    throw error;
  }
}

export async function createProductionServer(options = {}) {
  const env = loadEnv(options.env || {});
  const dataDir = resolve(options.dataDir || join(serverRoot, 'data')); mkdirSync(dataDir, { recursive: true });
  const logger = options.logger || createLogger(options.logOutput || console);
  if (String(env.NODE_ENV || '').toLowerCase() === 'production') assertProductionConfig(env, env.HOST || '127.0.0.1');
  const provider = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase();
  if (provider !== 'postgres') return createBirdfolioServer({ ...options, env, logger });
  const db = await (options.openPostgresDatabaseImpl || openPostgresDatabase)(env);
  try {
    await (options.migratePostgresImpl || migratePostgres)(db, { logger });
    const mediaStorage = options.mediaStorage || await createMediaStorage(env, dataDir, options.mediaStorageOptions);
    return createBirdfolioServer({ ...options, env, logger, dataDir, db, mediaStorage });
  } catch (error) { await db.close().catch(() => {}); throw error; }
}

export { timestampMilliseconds };

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const env = loadEnv(); const port = Number(env.PORT || 8787);
  const production = process.argv.includes('--release') || String(env.NODE_ENV || '').toLowerCase() === 'production';
  if (production) env.NODE_ENV = 'production';
  const host = env.HOST || (production ? '127.0.0.1' : '0.0.0.0'); assertProductionConfig(env, host);
  const logger = createLogger(); const server = await createProductionServer({ env, logger }); server.listen(port, host, () => logger.info('server.started', { host, port }));
}
