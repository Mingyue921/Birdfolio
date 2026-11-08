import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createServer as createHttpServer } from 'node:http';
import { createBirdfolioServer, timestampMilliseconds } from '../src/server.mjs';
import { identifyBird } from '../src/identification.mjs';
import { commercialImage, searchGbifBirds } from '../src/gbif.mjs';
import { speciesCatalog } from '../src/species-catalog.mjs';

const dataDir = mkdtempSync(join(tmpdir(), 'birdfolio-'));
const server = createBirdfolioServer({
  dataDir,
  databasePath: join(dataDir, 'test.db'),
  env: { VISION_API_URL: '', VISION_API_KEY: '', VISION_MODEL: '' },
  speciesCatalog: async ({ query }) => ({ source: 'GBIF', query, items: [{ id: 'gbif-1', name: 'Test bird' }], notice: 'test' })
});
let baseUrl = '';

before(async () => { await new Promise(resolve => server.listen(0, '127.0.0.1', resolve)); baseUrl = `http://127.0.0.1:${server.address().port}`; });
after(async () => { await new Promise(resolve => server.close(resolve)); rmSync(dataDir, { recursive: true, force: true }); });

test('health and seeded posts', async () => {
  assert.equal(speciesCatalog.length, 50);
  const health = await fetch(`${baseUrl}/api/health`).then(value => value.json());
  assert.equal(health.ok, true); assert.equal(health.aiMode, 'unavailable');
  const posts = await fetch(`${baseUrl}/api/posts`).then(value => value.json());
  assert.equal(posts.length, 2);
});

test('proxies the GBIF catalogue without requiring client credentials', async () => {
  const result = await fetch(`${baseUrl}/api/species?q=egret&limit=10`).then(value => value.json());
  assert.equal(result.source, 'GBIF');
  assert.equal(result.query, 'egret');
  assert.equal(result.items[0].id, 'gbif-1');

  const allowed = commercialImage([{ identifier: 'https://example.test/bird.jpg', creator: 'Observer', license: 'http://creativecommons.org/licenses/by/4.0/' }]);
  assert.equal(allowed.imageLicense, 'CC BY 4.0');
  const rejected = commercialImage([{ identifier: 'https://example.test/bird.jpg', license: 'http://creativecommons.org/licenses/by-nc/4.0/' }]);
  assert.equal(rejected.imageUrl, '');
});

test('GBIF network failures degrade to an offline catalogue response', async () => {
  const result = await searchGbifBirds({
    query: 'network-failure-test',
    fetchImpl: async () => { throw new Error('TLS_FAILED'); }
  });
  assert.equal(result.source, 'GBIF_UNAVAILABLE');
  assert.deepEqual(result.items, []);
  assert.match(result.notice, /离线图鉴/);
});

test('creates post, reactions, and comments', async () => {
  const post = await fetch(`${baseUrl}/api/posts`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ title: '校园观察', body: '看见一只树麻雀', speciesId: 'sparrow', userId: 'demo-user' }) }).then(value => value.json());
  assert.equal(post.title, '校园观察');
  const liked = await fetch(`${baseUrl}/api/posts/${post.id}/like`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ value: true }) }).then(value => value.json());
  assert.equal(liked.likeCount, 1);
  await fetch(`${baseUrl}/api/posts/${post.id}/comments`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ body: '记录得很好' }) });
  const comments = await fetch(`${baseUrl}/api/posts/${post.id}/comments`).then(value => value.json());
  assert.equal(comments.length, 1);
});

test('syncs newest observation and returns honest unavailable identification', async () => {
  const observation = { id: 'obs-test', userId: 'demo-user', speciesId: 'egret', updatedAt: '2026-09-20T10:00:00.000Z' };
  const saved = await fetch(`${baseUrl}/api/observations/obs-test`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(observation) });
  assert.equal(saved.status, 200);
  const observations = await fetch(`${baseUrl}/api/observations?userId=demo-user`).then(value => value.json());
  assert.equal(observations[0].id, 'obs-test');
  const result = await fetch(`${baseUrl}/api/identify/image`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ imageBase64: 'data:image/jpeg;base64,YQ==', placeName: '湿地', observedAt: '2026-09-20' }) }).then(value => value.json());
  assert.equal(result.mode, 'unavailable'); assert.equal(result.candidates.length, 0);
});

test('normalizes mixed observation timestamps and rejects stale or invalid updates', async () => {
  assert.equal(timestampMilliseconds('2026-09-20T10:00:00.000Z'), Date.parse('2026-09-20T10:00:00.000Z'));
  assert.equal(timestampMilliseconds('1758362400'), 1758362400000);
  assert.equal(timestampMilliseconds('1758362400000'), 1758362400000);

  const put = (payload) => fetch(`${baseUrl}/api/observations/obs-conflict`, {
    method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload)
  });
  assert.equal((await put({ id: 'obs-conflict', userId: 'demo-user', note: 'new', updatedAt: '2026-09-21T10:00:00.000Z' })).status, 200);
  assert.equal((await put({ id: 'obs-conflict', userId: 'demo-user', note: 'stale', updatedAt: '1758362400000' })).status, 200);
  let observations = await fetch(`${baseUrl}/api/observations?userId=demo-user`).then(value => value.json());
  assert.equal(observations.find(item => item.id === 'obs-conflict').note, 'new');

  assert.equal((await put({ id: 'obs-conflict', userId: 'demo-user', deleted: true, updatedAt: '1758362400' })).status, 200);
  observations = await fetch(`${baseUrl}/api/observations?userId=demo-user`).then(value => value.json());
  assert.ok(observations.some(item => item.id === 'obs-conflict'));
  assert.equal((await put({ id: 'obs-conflict', userId: 'demo-user', deleted: true, updatedAt: '2026-09-22T10:00:00.000Z' })).status, 200);
  observations = await fetch(`${baseUrl}/api/observations?userId=demo-user`).then(value => value.json());
  assert.ok(!observations.some(item => item.id === 'obs-conflict'));

  const invalid = await put({ id: 'obs-conflict', userId: 'demo-user', note: 'invalid', updatedAt: 'not-a-date' });
  assert.equal(invalid.status, 400);
});

test('rejects invalid post and invalid image', async () => {
  const post = await fetch(`${baseUrl}/api/posts`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
  assert.equal(post.status, 400);
  const image = await fetch(`${baseUrl}/api/identify/image`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
  assert.equal(image.status, 400);
});

test('vision requires all settings and distinguishes real provider candidates', async () => {
  const sample = { imageBase64: 'data:image/jpeg;base64,YQ==', placeName: '湿地', observedAt: '2026-09-20' };
  const incomplete = await identifyBird(sample, { VISION_API_KEY: 'test-key' });
  assert.equal(incomplete.mode, 'unavailable');

  let providerResponse = { choices: [{ message: { content: '```json\n[{"name":"普通翠鸟","scientificName":"Alcedo atthis","category":"翠鸟科","score":0.8,"reasons":["蓝绿色背羽","长嘴"],"description":"水边常见小型鸟。"}]\n```' } }] };
  let providerStatus = 200;
  const provider = createHttpServer(async (request, response) => {
    const chunks = []; for await (const chunk of request) chunks.push(chunk);
    const input = JSON.parse(Buffer.concat(chunks).toString());
    assert.equal(input.model, 'test-vision');
    response.writeHead(providerStatus, { 'content-type': 'application/json' });
    response.end(JSON.stringify(providerResponse));
  });
  await new Promise(resolve => provider.listen(0, '127.0.0.1', resolve));
  const env = { VISION_API_URL: `http://127.0.0.1:${provider.address().port}`, VISION_API_KEY: 'test-key', VISION_MODEL: 'test-vision' };
  try {
    const actual = await identifyBird(sample, env);
    assert.equal(actual.mode, 'provider');
    assert.equal(actual.candidates[0].speciesId, 'kingfisher');
    providerResponse = { choices: [{ message: { content: '[{"name":"测试鸟","scientificName":"Avis exemplum","category":"测试科","score":0.9,"reasons":["红色头部","白色翼斑"],"description":"目录外测试物种。"}]' } }] };
    const outside = await identifyBird(sample, env);
    assert.equal(outside.mode, 'provider');
    assert.equal(outside.candidates[0].inCatalog, false);
    assert.match(outside.candidates[0].speciesId, /^ai-/);
    providerStatus = 401;
    assert.equal((await identifyBird(sample, env)).mode, 'unavailable');
  } finally {
    await new Promise(resolve => provider.close(resolve));
  }
});
