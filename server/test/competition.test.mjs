import { afterEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createMemoryCache, createCacheRateLimiter } from '../src/platform/cache-provider.mjs';
import { createVisionProvider } from '../src/platform/vision-provider.mjs';
import { createBirdfolioServer } from '../src/server.mjs';
import { cleanupExpiredDemoAccounts } from '../src/demo-cleanup.mjs';

const roots = [];
afterEach(() => { while (roots.length) rmSync(roots.pop(), { recursive: true, force: true }); });
const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');

async function listening(options = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-competition-')); roots.push(dir);
  const server = createBirdfolioServer({ dataDir: dir, databasePath: join(dir, 'test.db'), scheduleMediaCleanupImpl: () => () => {}, scheduleDemoCleanupImpl: () => () => {}, ...options });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  return { server, origin: `http://127.0.0.1:${server.address().port}` };
}

async function request(origin, path, init = {}) {
  const response = await fetch(origin + path, { ...init, headers: { 'content-type': 'application/json', ...(init.headers || {}) } });
  return { response, body: await response.json() };
}

test('memory cache honors TTL and rate limiter fails closed', async () => {
  let now = 1000; const cache = createMemoryCache({ clock: () => now });
  await cache.set('candidate', 'value', 2); assert.equal(await cache.get('candidate'), 'value'); now = 3001; assert.equal(await cache.get('candidate'), null);
  const rate = createCacheRateLimiter(cache); await rate('demo:ip', 2, 60000); await rate('demo:ip', 2, 60000);
  await assert.rejects(rate('demo:ip', 2, 60000), /RATE_LIMITED/);
  const failed = createCacheRateLimiter({ async increment() { throw new Error('DCS_DOWN'); } });
  await assert.rejects(failed('demo:ip', 2, 60000), /RATE_LIMIT_DEPENDENCY_UNAVAILABLE/);
});

test('Huawei MaaS compatible provider maps auth, quota and JSON failures', async () => {
  const env = { VISION_PROVIDER: 'huawei_maas', VISION_API_URL: 'https://maas.example/v1/chat/completions', VISION_API_KEY: 'secret', VISION_MODEL: 'vision-model' };
  const provider = status => createVisionProvider(env, { fetchImpl: async () => ({ status, ok: status === 200, async json() { if (status === 200) return { choices: [{ message: { content: '[]' } }] }; throw new Error('bad json'); } }) });
  assert.equal((await provider(200).identify({ imageBase64: 'data:image/png;base64,aA==' })).provider, 'huawei_maas');
  await assert.rejects(provider(401).identify({}), /PROVIDER_AUTH_ERROR/);
  await assert.rejects(provider(429).identify({}), /PROVIDER_QUOTA_EXCEEDED/);
});

test('competition demo sessions are isolated and AI candidates are cached', async () => {
  let calls = 0;
  const visionProvider = { name: 'huawei_maas', modelVersion: 'test-model', configured: true, async identify() { calls += 1; return { provider: 'huawei_maas', modelVersion: 'test-model', elapsedMs: 12, content: JSON.stringify([{ name: '白鹭', scientificName: 'Egretta garzetta', category: '鹭科', score: 0.88, reasons: ['白色体羽', '黑色长喙'] }]) }; } };
  const cache = createMemoryCache(); const { server, origin } = await listening({ cache, visionProvider, env: { DEPLOYMENT_PROFILE: 'competition', COMPETITION_DEMO_LOGIN: 'true', DEMO_MODE: 'false', REQUIRE_AUTH: 'true', VISION_API_URL: 'https://maas.example', VISION_API_KEY: 'test-key', VISION_MODEL: 'test-model', VISION_PROVIDER: 'huawei_maas' } });
  try {
    const first = await request(origin, '/api/auth/demo-session', { method: 'POST', body: '{}' }); const second = await request(origin, '/api/auth/demo-session', { method: 'POST', body: '{}' });
    assert.equal(first.response.status, 200); assert.notEqual(first.body.userId, second.body.userId); assert.ok(first.body.accountExpiresAt > Date.now());
    const auth = { authorization: `Bearer ${first.body.accessToken}` };
    const observations = await request(origin, '/api/observations', { headers: auth }); assert.equal(observations.body.length, 2); assert.ok(observations.body.every(item => item.notes === '比赛演示种子数据'));
    const media = await request(origin, '/api/media', { method: 'POST', headers: auth, body: JSON.stringify({ dataUrl: `data:image/png;base64,${png.toString('base64')}` }) }); assert.equal(media.response.status, 201);
    const identifyInput = JSON.stringify({ mediaId: media.body.mediaId, placeName: '福州', observedAt: '2026-11-11T08:00:00.000Z', habitat: 'wetland' });
    const identified = await request(origin, '/api/identify/image', { method: 'POST', headers: auth, body: identifyInput });
    const cached = await request(origin, '/api/identify/image', { method: 'POST', headers: auth, body: identifyInput });
    assert.equal(identified.body.provider, 'huawei_maas'); assert.equal(identified.body.cacheHit, false); assert.equal(cached.body.cacheHit, true); assert.equal(calls, 1);
  } finally { await new Promise(resolve => server.close(resolve)); }
});

test('competition shortcut is unavailable outside the competition profile', async () => {
  const { server, origin } = await listening({ env: {} });
  try { const response = await request(origin, '/api/auth/demo-session', { method: 'POST', body: '{}' }); assert.equal(response.response.status, 403); assert.equal(response.body.error, 'DEMO_LOGIN_DISABLED'); }
  finally { await new Promise(resolve => server.close(resolve)); }
});

test('expired competition accounts and isolated records are removed together', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-demo-cleanup-')); roots.push(dir);
  const { openDatabase } = await import('../src/database.mjs'); const db = openDatabase(join(dir, 'cleanup.db'), { seed: false });
  const now = Date.now();
  db.prepare("INSERT INTO users(id,email,display_name,created_at,updated_at,deleted_at) VALUES(?,?,?,?,?,'')").run('expired-demo', 'expired@competition.invalid', 'Demo', new Date(now - 1000).toISOString(), new Date(now - 1000).toISOString());
  db.prepare('INSERT INTO demo_accounts(user_id,expires_at,created_at) VALUES(?,?,?)').run('expired-demo', now - 1, now - 1000);
  db.prepare("INSERT INTO observations(id,user_id,payload,updated_at,deleted_at,version) VALUES(?,?,?,?, '',1)").run('expired-observation', 'expired-demo', '{}', String(now - 10));
  const result = await cleanupExpiredDemoAccounts(db, { now, storage: { async deleteObject() { return true; } } });
  assert.equal(result.removed, 1); assert.equal(db.prepare('SELECT COUNT(*) AS count FROM users WHERE id=?').get('expired-demo').count, 0); assert.equal(db.prepare('SELECT COUNT(*) AS count FROM observations WHERE user_id=?').get('expired-demo').count, 0); db.close();
});
