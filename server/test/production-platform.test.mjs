import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import pg from 'pg';
import { openDatabase } from '../src/database.mjs';
import { saveMedia } from '../src/media.mjs';
import { createMailProvider } from '../src/platform/mail-provider.mjs';
import { createLocalMediaStorage } from '../src/platform/media-storage.mjs';
import { createObsMediaStorage } from '../src/platform/media-storage.mjs';
import { createPostgresAdapter } from '../src/platform/postgres.mjs';
import { migratePostgres } from '../src/platform/postgres-migrations.mjs';
import { createPersistentRateLimiter } from '../src/platform/rate-limiter.mjs';
import { protectCommunityLocation, protectObservationLocation } from '../src/privacy/location-policy.mjs';
import { createBirdfolioServer } from '../src/server.mjs';

const { Pool } = pg;
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');

test('media object is rolled back when database insertion fails', async () => {
  const objects = new Map();
  const storage = { async putObject(key, value) { objects.set(key, value); return { key, locator: `memory://${key}` }; }, async deleteObject(key) { objects.delete(key); return true; } };
  const db = { prepare() { return { async run() { throw new Error('DB_WRITE_FAILED'); } }; } };
  await assert.rejects(saveMedia({ db, storage, userId: 'user', buffer: png, mime: 'image/png' }), /DB_WRITE_FAILED/);
  assert.equal(objects.size, 0);
});

test('storage failure does not create a media database row', async () => {
  let inserts = 0;
  const db = { prepare() { return { async run() { inserts += 1; } }; } };
  const storage = { async putObject() { throw new Error('OBS_DOWN'); }, async deleteObject() { return true; } };
  await assert.rejects(saveMedia({ db, storage, userId: 'user', buffer: png, mime: 'image/png' }), /MEDIA_STORAGE_UNAVAILABLE/);
  assert.equal(inserts, 0);
});

test('failed object rollback retains an expired cleanup record', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-orphan-')); const db = openDatabase(join(dir, 'orphan.db'), { seed: false });
  const objects = new Map(); let insertCount = 0;
  const originalPrepare = db.prepare.bind(db);
  db.prepare = sql => {
    if (String(sql).startsWith('INSERT INTO posts')) return { run() { throw new Error('POST_WRITE_FAILED'); } };
    return originalPrepare(sql);
  };
  const storage = { kind: 'test', async putObject(key, value) { objects.set(key, value); return { key, locator: `memory://${key}` }; }, async deleteObject() { return false; }, async getObject(key) { return objects.get(key); }, async health() { return true; } };
  const server = createBirdfolioServer({ dataDir: dir, db, mediaStorage: storage, env: {}, scheduleMediaCleanupImpl: () => () => {} });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const response = await fetch(`http://127.0.0.1:${server.address().port}/api/posts`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ title: 'title', body: 'body', imageBase64: `data:image/png;base64,${png.toString('base64')}` }) });
    assert.equal(response.status, 500); insertCount = originalPrepare('SELECT COUNT(*) AS count FROM media WHERE expires_at<=?').get(Date.now()).count;
    assert.equal(insertCount, 1); assert.equal(objects.size, 1);
  } finally { await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true, force: true }); }
});

test('OBS adapter uses private object operations and surfaces provider failures', async () => {
  const calls = [];
  const client = {
    putObject(input, callback) { calls.push(['put', input]); callback(null, { CommonMsg: { Status: 200 } }); },
    getObject(input, callback) { calls.push(['get', input]); callback(null, { CommonMsg: { Status: 200 }, InterfaceResult: { Content: png } }); },
    deleteObject(input, callback) { calls.push(['delete', input]); callback(null, { CommonMsg: { Status: 204 } }); },
    getBucketMetadata(input, callback) { calls.push(['health', input]); callback(null, { CommonMsg: { Status: 200 } }); }
  };
  const storage = await createObsMediaStorage({ OBS_BUCKET: 'private-bucket', OBS_ENDPOINT: 'https://obs.example', OBS_ACCESS_KEY_ID: 'id', OBS_SECRET_ACCESS_KEY: 'secret' }, { obsModule: {}, client });
  assert.match((await storage.putObject('bird.png', png, 'image/png')).locator, /^obs:\/\/private-bucket\//);
  assert.deepEqual(await storage.getObject('bird.png'), png); assert.equal(await storage.deleteObject('bird.png'), true); assert.equal(await storage.health(), true);
  assert.deepEqual(calls.map(item => item[0]), ['put', 'get', 'delete', 'health']);
  const failed = await createObsMediaStorage({ OBS_BUCKET: 'private-bucket' }, { obsModule: {}, client: { putObject(input, callback) { callback(new Error('OBS_DOWN')); } } });
  await assert.rejects(failed.putObject('bird.png', png), /OBS_DOWN/);
});

test('local media storage rejects traversal and round-trips bytes', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-storage-'));
  try {
    const storage = createLocalMediaStorage(dir);
    await storage.putObject('bird.png', png, 'image/png');
    assert.deepEqual(await storage.getObject('bird.png'), png);
    await assert.rejects(storage.putObject('../outside.png', png), /INVALID_MEDIA_KEY/);
    assert.equal(await storage.deleteObject('bird.png'), true);
    assert.equal(await storage.getObject('bird.png'), null);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('persistent rate limiter survives limiter recreation', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-rate-')); const db = openDatabase(join(dir, 'rate.db'), { seed: false });
  try {
    await createPersistentRateLimiter(db)('login:user', 2, 60_000);
    await createPersistentRateLimiter(db)('login:user', 2, 60_000);
    await assert.rejects(createPersistentRateLimiter(db)('login:user', 2, 60_000), /RATE_LIMITED/);
  } finally { db.close(); rmSync(dir, { recursive: true, force: true }); }
});

test('mail provider reports success and provider failure without exposing credentials', async () => {
  let sent;
  const success = createMailProvider({ MAIL_PROVIDER_URL: 'https://mail.example/send', MAIL_PROVIDER_TOKEN: 'secret' }, { fetchImpl: async (url, init) => { sent = { url, init }; return { ok: true }; } });
  await success.sendVerificationCode({ email: 'user@example.com', code: '123456', expiresIn: 600 });
  assert.equal(sent.url, 'https://mail.example/send'); assert.equal(JSON.parse(sent.init.body).template, 'birdfolio-login-code');
  const failed = createMailProvider({ MAIL_PROVIDER_URL: 'https://mail.example/send' }, { fetchImpl: async () => ({ ok: false }) });
  await assert.rejects(failed.sendVerificationCode({ email: 'user@example.com', code: '123456', expiresIn: 600 }), /PROVIDER_UNAVAILABLE/);
});

test('server-side location policy keeps private exact coordinates and blurs protected records', () => {
  const exact = protectObservationLocation({ speciesId: 'egret', latitude: 26.123456, longitude: 119.987654, fuzzyLocation: false });
  assert.equal(exact.latitude, 26.123456); assert.equal(exact.locationPrecision, 'exact');
  const fuzzy = protectObservationLocation({ speciesId: 'egret', latitude: 26.123456, longitude: 119.987654, fuzzyLocation: true });
  assert.equal(fuzzy.latitude, 26.12); assert.equal(fuzzy.longitude, 119.99); assert.equal(fuzzy.locationPrecision, 'coarse');
  const sensitive = protectObservationLocation({ speciesId: 'rare-bird', latitude: 26.123456, longitude: 119.987654 }, { SENSITIVE_SPECIES_IDS: 'rare-bird' });
  assert.equal(sensitive.latitude, 26.12); assert.equal(sensitive.fuzzyLocation, true);
  assert.deepEqual(protectCommunityLocation({ latitude: 26.1, longitude: 119.1, coordinates: [119.1, 26.1], title: 'bird' }), { title: 'bird', locationPrecision: 'place-name' });
});

test('liveness succeeds while readiness fails closed on dependency failure', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-health-'));
  const storage = { kind: 'test', async health() { throw new Error('STORAGE_DOWN'); }, async deleteObject() { return true; }, async getObject() { return null; }, async putObject() {} };
  const server = createBirdfolioServer({ dataDir: dir, databasePath: join(dir, 'health.db'), mediaStorage: storage, scheduleMediaCleanupImpl: () => () => {} });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    assert.equal((await fetch(`${origin}/health/live`)).status, 200);
    const ready = await fetch(`${origin}/health/ready`); assert.equal(ready.status, 503); assert.equal((await ready.json()).error, 'DEPENDENCY_UNAVAILABLE');
  } finally { await new Promise(resolve => server.close(resolve)); rmSync(dir, { recursive: true, force: true }); }
});

test('production factory refuses incomplete release configuration', async () => {
  const { createProductionServer } = await import('../src/server.mjs');
  await assert.rejects(createProductionServer({ env: { NODE_ENV: 'production' } }), /PRODUCTION_CONFIG_INVALID/);
});

const integrationUrl = String(process.env.TEST_DATABASE_URL || '').trim();
test('PostgreSQL migrations are idempotent and core API contract matches SQLite', { skip: !integrationUrl }, async () => {
  const admin = new Pool({ connectionString: integrationUrl, ssl: false });
  const schema = `birdfolio_test_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  await admin.query(`CREATE SCHEMA "${schema}"`);
  const scopedUrl = new URL(integrationUrl); scopedUrl.searchParams.set('options', `-c search_path=${schema}`);
  const pool = new Pool({ connectionString: scopedUrl.toString(), max: 1, ssl: false });
  const db = createPostgresAdapter(pool); let server;
  try {
    await migratePostgres(db); await migratePostgres(db);
    assert.deepEqual((await db.prepare('SELECT version FROM schema_migrations ORDER BY version').all()).map(row => Number(row.version)), [1, 2]);
    await assert.rejects(migratePostgres(db, { migrationList: [{ version: 2, name: 'rollback_probe', sql: 'CREATE TABLE rollback_probe(id INTEGER); SELECT * FROM table_that_does_not_exist;' }] }));
    assert.equal(await db.prepare("SELECT to_regclass('rollback_probe') AS name").get().then(row => row.name), null);
    assert.deepEqual((await db.prepare('SELECT version FROM schema_migrations ORDER BY version').all()).map(row => Number(row.version)), [1, 2]);
    const dir = mkdtempSync(join(tmpdir(), 'birdfolio-pg-'));
    server = createBirdfolioServer({ dataDir: dir, db, mediaStorage: createLocalMediaStorage(dir), env: { DATABASE_PROVIDER: 'postgres', REQUIRE_AUTH: 'true', AUTH_DEBUG_CODES: 'true', DEMO_MODE: 'false' } });
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); const origin = `http://127.0.0.1:${server.address().port}`;
    const request = async (path, init = {}) => { const response = await fetch(origin + path, { ...init, headers: { 'content-type': 'application/json', ...(init.headers || {}) } }); return { response, body: await response.json() }; };
    const code = await request('/api/auth/request-code', { method: 'POST', body: JSON.stringify({ email: 'postgres@example.com' }) });
    const session = await request('/api/auth/verify-code', { method: 'POST', body: JSON.stringify({ email: 'postgres@example.com', code: code.body.debugCode }) });
    const headers = { authorization: `Bearer ${session.body.accessToken}` };
    const saved = await request('/api/observations/pg-observation', { method: 'PUT', headers, body: JSON.stringify({ speciesId: 'egret', latitude: 26.1234, longitude: 119.9876, fuzzyLocation: true, updatedAt: Date.now() }) });
    assert.equal(saved.body.status, 'applied');
    const observations = await request('/api/observations', { headers }); assert.equal(observations.body[0].latitude, 26.12);
    const media = await request('/api/media', { method: 'POST', headers, body: JSON.stringify({ dataUrl: `data:image/png;base64,${png.toString('base64')}` }) }); assert.equal(media.response.status, 201);
    const post = await request('/api/posts', { method: 'POST', headers, body: JSON.stringify({ title: 'Postgres', body: 'contract', latitude: 26.1, longitude: 119.1 }) });
    assert.equal(post.response.status, 201); assert.equal(Object.hasOwn(post.body, 'latitude'), false);
    const sync = await request('/api/sync/push', { method: 'POST', headers: { ...headers, 'idempotency-key': 'pg-sync-1' }, body: JSON.stringify({ mutations: [{ mutationId: 'pg-mutation', entity: 'observation', entityId: 'pg-sync', operation: 'upsert', updatedAt: Date.now(), payload: JSON.stringify({ speciesId: 'sparrow' }) }] }) }); assert.equal(sync.response.status, 200);
    const exported = await request('/api/account/export', { method: 'POST', headers, body: '{}' }); assert.equal(exported.response.status, 200);
    const deleted = await request('/api/account', { method: 'DELETE', headers }); assert.equal(deleted.response.status, 200);
    assert.equal((await request('/api/me', { headers })).response.status, 401);
    await new Promise(resolve => server.close(resolve)); server = null; rmSync(dir, { recursive: true, force: true });
  } finally {
    if (server) await new Promise(resolve => server.close(resolve)); else await pool.end().catch(() => {});
    await admin.query(`DROP SCHEMA IF EXISTS "${schema}" CASCADE`); await admin.end();
  }
});
