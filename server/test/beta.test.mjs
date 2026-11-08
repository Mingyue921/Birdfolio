import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createBirdfolioServer } from '../src/server.mjs';

const dataDir = mkdtempSync(join(tmpdir(), 'birdfolio-beta-'));
const server = createBirdfolioServer({
  dataDir,
  databasePath: join(dataDir, 'beta.db'),
  env: { AUTH_DEBUG_CODES: 'true', VISION_API_URL: '', VISION_API_KEY: '', VISION_MODEL: '' }
});
let baseUrl = '';
const pngDataUrl = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

before(async () => { await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); baseUrl = `http://127.0.0.1:${server.address().port}`; });
after(async () => { await new Promise(resolve => server.close(resolve)); rmSync(dataDir, { recursive: true, force: true }); });

async function request(path, init = {}) {
  const response = await fetch(baseUrl + path, { ...init, headers: { 'content-type': 'application/json', ...(init.headers || {}) } });
  return { response, body: await response.json() };
}

test('email code session provides client-compatible tokens and isolates observations', async () => {
  const requested = await request('/api/auth/request-code', { method: 'POST', body: JSON.stringify({ email: 'beta-a@example.com' }) });
  assert.equal(requested.response.status, 200); assert.equal(requested.body.accepted, true); assert.match(requested.body.debugCode, /^\d{6}$/);
  const verified = await request('/api/auth/verify-code', { method: 'POST', body: JSON.stringify({ email: 'beta-a@example.com', code: requested.body.debugCode }) });
  assert.equal(verified.response.status, 200); assert.ok(verified.body.accessToken); assert.ok(verified.body.userId); assert.ok(verified.body.expiresAt);
  const authHeaders = { authorization: `Bearer ${verified.body.accessToken}` };
  const me = await request('/api/me', { headers: authHeaders }); assert.equal(me.response.status, 200); assert.equal(me.body.email, 'beta-a@example.com');
  const saved = await request('/api/observations/beta-observation', { method: 'PUT', headers: authHeaders, body: JSON.stringify({ id: 'beta-observation', speciesId: 'egret', updatedAt: Date.now() }) });
  assert.equal(saved.body.status, 'applied');
  const guest = await request('/api/observations?userId=beta-a@example.com'); assert.equal(guest.body.some(item => item.id === 'beta-observation'), false);
});

test('media upload validates image magic bytes and sync push is idempotent', async () => {
  const requested = await request('/api/auth/request-code', { method: 'POST', body: JSON.stringify({ email: 'beta-b@example.com' }) });
  const verified = await request('/api/auth/verify-code', { method: 'POST', body: JSON.stringify({ email: 'beta-b@example.com', code: requested.body.debugCode }) });
  const authHeaders = { authorization: `Bearer ${verified.body.accessToken}` };
  const media = await request('/api/media', { method: 'POST', headers: authHeaders, body: JSON.stringify({ dataUrl: pngDataUrl, fileName: 'bird.png', mimeType: 'image/png' }) });
  assert.equal(media.response.status, 201); assert.equal(media.body.mimeType, 'image/png'); assert.equal(media.body.width, 1);
  const missingMedia = await request('/api/identify/image', { method: 'POST', headers: authHeaders, body: JSON.stringify({ placeName: '湿地', observedAt: '2026-09-20' }) });
  assert.equal(missingMedia.response.status, 400); assert.equal(missingMedia.body.error, 'MEDIA_REQUIRED');
  const invalid = await request('/api/media', { method: 'POST', headers: authHeaders, body: JSON.stringify({ dataUrl: 'data:image/png;base64,YQ==' }) });
  assert.equal(invalid.response.status, 400); assert.equal(invalid.body.error, 'INVALID_IMAGE_MAGIC');
  const corrupt = await request('/api/media', { method: 'POST', headers: authHeaders, body: JSON.stringify({ dataUrl: 'data:image/png;base64,iVBORw0KGgoAAAAAA==' }) });
  assert.equal(corrupt.response.status, 400); assert.equal(corrupt.body.error, 'INVALID_IMAGE_CONTENT');
  const mutation = { mutationId: 'beta-mutation', entity: 'observation', entityId: 'sync-observation', operation: 'upsert', updatedAt: new Date().toISOString(), payload: JSON.stringify({ speciesId: 'egret' }) };
  const syncInit = { method: 'POST', headers: { ...authHeaders, 'idempotency-key': 'beta-idempotency' }, body: JSON.stringify({ mutations: [mutation], idempotencyKey: 'beta-idempotency' }) };
  const first = await request('/api/sync/push', syncInit); const second = await request('/api/sync/push', syncInit);
  assert.equal(first.body.results[0].result, 'applied'); assert.deepEqual(second.body, first.body);
  const pull = await request('/api/sync/pull', { headers: authHeaders }); assert.equal(pull.body.mutations[0].entity, 'observation');
});

test('account export exposes a portable bundle and private routes reject missing auth in release mode', async () => {
  const requested = await request('/api/auth/request-code', { method: 'POST', body: JSON.stringify({ email: 'beta-c@example.com' }) });
  const verified = await request('/api/auth/verify-code', { method: 'POST', body: JSON.stringify({ email: 'beta-c@example.com', code: requested.body.debugCode }) });
  const exported = await request('/api/account/export', { method: 'POST', headers: { authorization: `Bearer ${verified.body.accessToken}` }, body: '{}' });
  assert.equal(exported.response.status, 200); assert.equal(exported.body.format, 'birdfolio-json'); assert.equal(typeof exported.body.payload, 'string');
  const releaseDir = mkdtempSync(join(tmpdir(), 'birdfolio-release-'));
  const releaseServer = createBirdfolioServer({ dataDir: releaseDir, databasePath: join(releaseDir, 'release.db'), env: { REQUIRE_AUTH: 'true', AUTH_DEBUG_CODES: 'true' } });
  await new Promise(resolve => releaseServer.listen(0, '127.0.0.1', resolve));
  try { const response = await fetch(`http://127.0.0.1:${releaseServer.address().port}/api/posts`); assert.equal(response.status, 401); } finally { await new Promise(resolve => releaseServer.close(resolve)); rmSync(releaseDir, { recursive: true, force: true }); }
});
