import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createLogger } from '../src/logger.mjs';
import { runMediaCleanup } from '../src/jobs/cleanup-media.mjs';
import { createBirdfolioServer } from '../src/server.mjs';

test('logger recursively redacts secrets, verification data, photos, coordinates, and local paths', () => {
  const lines = []; const output = { log: line => lines.push(line), warn: line => lines.push(line), error: line => lines.push(line) };
  createLogger(output).info('redaction.test', {
    authorization: 'Bearer token-value', cookie: 'session=cookie-value', requestBody: 'body-value',
    nested: { access_token: 'access-value', refreshToken: 'refresh-value', apiKey: 'key-value', password: 'password-value', debugCode: '123456', imageBase64: 'photo-content', photoUri: 'photo-uri-value', latitude: 39.9, longitude: 116.4, exactLocation: { street: 'exact-street' }, filePath: 'C:\\private\\bird.jpg' },
    items: [{ data_url: 'data:image/png;base64,secret' }, { coordinates: [116.4, 39.9] }]
  });
  assert.equal(lines.length, 1);
  for (const secret of ['token-value', 'cookie-value', 'body-value', 'access-value', 'refresh-value', 'key-value', 'password-value', '123456', 'photo-content', 'photo-uri-value', 'exact-street', '116.4', '39.9', 'bird.jpg', 'base64,secret']) assert.doesNotMatch(lines[0], new RegExp(secret.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.match(lines[0], /\[REDACTED\]/);
});

test('assembly failure closes an opened database exactly once', () => {
  let closes = 0; const db = { close() { closes += 1; } };
  assert.throws(() => createBirdfolioServer({ dataDir: tmpdir(), openDatabaseImpl: () => db, createAuthStoreImpl() { throw new Error('ASSEMBLY_FAILED'); } }), /ASSEMBLY_FAILED/);
  assert.equal(closes, 1);
});

test('server close is idempotent and stops background cleanup once', async () => {
  let closes = 0; let stops = 0;
  const db = { close() { closes += 1; } };
  const server = createBirdfolioServer({ dataDir: tmpdir(), openDatabaseImpl: () => db, createAuthStoreImpl: () => ({}), createObservationServiceImpl: () => ({ rows() { return []; }, write() {} }), scheduleMediaCleanupImpl: () => () => { stops += 1; } });
  await new Promise(resolve => server.close(resolve));
  await new Promise(resolve => server.close(resolve));
  assert.equal(closes, 1); assert.equal(stops, 1);
});

test('standalone cleanup closes its database on success and failure', () => {
  let closes = 0; const db = { close() { closes += 1; } };
  assert.deepEqual(runMediaCleanup({ env: {}, openDatabaseImpl: () => db, cleanupImpl: () => ({ scanned: 4, removed: 1, skipped: 3 }) }), { scanned: 4, removed: 1, skipped: 3 });
  assert.equal(closes, 1);
  assert.throws(() => runMediaCleanup({ env: {}, openDatabaseImpl: () => db, cleanupImpl() { throw new Error('CLEANUP_FAILED'); } }), /CLEANUP_FAILED/);
  assert.equal(closes, 2);
  assert.throws(() => runMediaCleanup({ env: {}, openDatabaseImpl: () => ({ close() { throw new Error('CLOSE_FAILED'); } }), cleanupImpl: () => ({ scanned: 0, removed: 0, skipped: 0 }) }), /CLOSE_FAILED/);
});

const dataDir = mkdtempSync(join(tmpdir(), 'birdfolio-acceptance-'));
const logLines = [];
const server = createBirdfolioServer({
  dataDir, databasePath: join(dataDir, 'acceptance.db'), logOutput: { log: line => logLines.push(line), warn: line => logLines.push(line), error: line => logLines.push(line) },
  env: { REQUIRE_AUTH: 'true', AUTH_DEBUG_CODES: 'true', VISION_API_URL: '', VISION_API_KEY: '', VISION_MODEL: '' },
  speciesCatalog: async ({ query }) => ({ source: 'GBIF', query, items: [], notice: 'test' })
});
let baseUrl = ''; let accessToken = '';

before(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); baseUrl = `http://127.0.0.1:${server.address().port}`;
  const requested = await api('/api/auth/request-code', { method: 'POST', body: JSON.stringify({ email: 'contract@example.com' }) });
  const verified = await api('/api/auth/verify-code', { method: 'POST', body: JSON.stringify({ email: 'contract@example.com', code: requested.body.debugCode }) });
  accessToken = verified.body.accessToken;
});
after(async () => { await new Promise(resolve => server.close(resolve)); rmSync(dataDir, { recursive: true, force: true }); });

async function api(path, init = {}) {
  const response = await fetch(baseUrl + path, { ...init, headers: { 'content-type': 'application/json', ...(init.headers || {}) } });
  return { response, body: await response.json() };
}

test('core API contracts retain methods, URLs, auth requirements, and response fields', async () => {
  const unauthenticated = [
    ['GET', '/api/me'], ['GET', '/api/posts'], ['POST', '/api/account/export'], ['GET', '/api/media/missing'], ['GET', '/api/sync/pull']
  ];
  for (const [method, path] of unauthenticated) {
    const result = await api(path, { method, body: method === 'POST' ? '{}' : undefined });
    assert.equal(result.response.status, 401, `${method} ${path}`); assert.equal(result.body.error, 'AUTH_REQUIRED');
  }
  const authorization = { authorization: `Bearer ${accessToken}` };
  const contracts = [
    { method: 'GET', path: '/api/health', status: 200, fields: ['ok', 'service', 'aiMode', 'auth', 'version'] },
    { method: 'GET', path: '/api/species?q=egret', status: 200, fields: ['source', 'query', 'items', 'notice'] },
    { method: 'GET', path: '/api/me', status: 200, auth: true, fields: ['id', 'email', 'user'] },
    { method: 'GET', path: '/api/posts', status: 200, auth: true, array: true },
    { method: 'GET', path: '/api/observations', status: 200, auth: true, array: true },
    { method: 'POST', path: '/api/account/export', status: 200, auth: true, body: '{}', fields: ['format', 'generatedAt', 'payload', 'observations', 'posts', 'comments'] },
    { method: 'GET', path: '/api/sync/pull', status: 200, auth: true, fields: ['ok', 'cursor', 'nextCursor', 'records', 'mutations'] },
    { method: 'POST', path: '/api/identify/image', status: 400, auth: true, body: '{}', fields: ['error', 'requestId'] }
  ];
  for (const contract of contracts) {
    const result = await api(contract.path, { method: contract.method, headers: contract.auth ? authorization : {}, body: contract.body });
    assert.equal(result.response.status, contract.status, `${contract.method} ${contract.path}`);
    if (contract.array) assert.ok(Array.isArray(result.body));
    for (const field of contract.fields || []) assert.ok(Object.hasOwn(result.body, field), `${contract.path} missing ${field}`);
  }
});

test('failed request emits one normalized structured log with stable error category', async () => {
  const beforeCount = logLines.length;
  const result = await api('/api/observations/private-id?secret=query-value', { method: 'PUT', headers: { authorization: `Bearer ${accessToken}` }, body: JSON.stringify({ updatedAt: 'invalid' }) });
  assert.equal(result.response.status, 400);
  const records = logLines.slice(beforeCount).map(line => JSON.parse(line)).filter(record => record.event === 'http.request_completed');
  assert.equal(records.length, 1);
  assert.equal(records[0].route, '/api/observations/:observationId'); assert.equal(records[0].status, 400); assert.equal(records[0].errorCategory, 'validation');
  assert.equal(typeof records[0].elapsedMs, 'number'); assert.ok(records[0].requestId); assert.equal(records[0].method, 'PUT');
  assert.doesNotMatch(JSON.stringify(records[0]), /query-value|private-id/);
});
