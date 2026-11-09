import { timestampMilliseconds } from './observation-routes.mjs';

export async function handleSyncRoutes(ctx) {
  const { req, res, url, env, rid, db, actor, body, json, observationRows, writeObservation } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/sync/push') {
    const { userId } = await actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const idempotencyKey = String(req.headers['idempotency-key'] || input.idempotencyKey || '').trim().slice(0, 160);
    if (idempotencyKey) { const cached = await db.prepare('SELECT response_json FROM sync_operations WHERE user_id=? AND idempotency_key=?').get(userId, idempotencyKey); if (cached) { json(res, 200, JSON.parse(cached.response_json), env, rid); return true; } }
    const incoming = Array.isArray(input.mutations) ? input.mutations.map(mutation => { let parsed = {}; try { parsed = typeof mutation.payload === 'string' ? JSON.parse(mutation.payload) : (mutation.payload || {}); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); } return { ...parsed, entity: mutation.entity || 'observation', id: mutation.entityId || parsed.id, updatedAt: mutation.updatedAt || parsed.updatedAt, deleted: mutation.operation === 'delete', mutationId: mutation.mutationId }; }) : (Array.isArray(input.operations) ? input.operations : Array.isArray(input.changes) ? input.changes : Array.isArray(input.records) ? input.records : [input]);
    const rawResults = await Promise.all(incoming.map(async operation => { if (operation.entity && operation.entity !== 'observation') return { status: 'rejected', id: operation.id || '', updatedAt: '', message: '当前同步协议仅支持观察记录' }; let payload = operation.payload; if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); } } return await writeObservation(userId, { ...(payload || {}), ...operation, userId }, operation.id || payload?.id); }));
    const results = rawResults.map((result, index) => ({ ...result, mutationId: incoming[index].mutationId || '', entityId: result.id, result: result.status === 'applied' ? 'applied' : result.status === 'rejected' ? 'rejected' : 'conflict', serverUpdatedAt: result.updatedAt, message: result.message || (result.status === 'conflict' ? '服务器已有更新版本' : '') }));
    const response = { ok: true, results, applied: results.filter(item => item.result === 'applied').length, conflicts: results.filter(item => item.result === 'conflict').length, cursor: String(Date.now()), nextCursor: String(Date.now()) };
    if (idempotencyKey) await db.prepare('INSERT INTO sync_operations(idempotency_key,user_id,response_json,created_at) VALUES(?,?,?,?) ON CONFLICT(user_id,idempotency_key) DO UPDATE SET response_json=excluded.response_json,created_at=excluded.created_at').run(idempotencyKey, userId, JSON.stringify(response), Date.now());
    json(res, 200, response, env, rid); return true;
  }
  if (req.method === 'GET' && url.pathname === '/api/sync/pull') {
    const { userId } = await actor(req, {}, true); const cursor = timestampMilliseconds(url.searchParams.get('cursor') || ''); const highWaterMark = Date.now(); const records = await observationRows(userId, true, cursor);
    const mutations = records.map(record => ({ mutationId: `server-${record.id}-${record.version || 1}`, entity: 'observation', entityId: record.id, operation: record.deleted ? 'delete' : 'upsert', updatedAt: record.updatedAt, payload: JSON.stringify(record) }));
    json(res, 200, { ok: true, cursor: String(highWaterMark), nextCursor: String(highWaterMark), hasMore: false, records, mutations }, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/sync/resolve') {
    const { userId } = await actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const resolution = String(input.resolution || 'local'); if (!['local', 'remote', 'server'].includes(resolution)) throw new Error('INVALID_RESOLUTION');
    const payload = input.local || input.server || input.payload;
    if (!payload) { const unchanged = { status: 'unchanged', result: 'unchanged', entityId: input.entityId || '' }; json(res, 200, { ok: true, resolution, result: unchanged, results: [unchanged] }, env, rid); return true; }
    const resolved = await writeObservation(userId, { ...payload, userId, updatedAt: payload.updatedAt || Date.now() }, input.entityId || payload.id); const normalized = { ...resolved, result: resolved.status === 'applied' ? 'applied' : 'conflict', entityId: resolved.id, serverUpdatedAt: resolved.updatedAt, mutationId: input.mutationId || '' };
    json(res, 200, { ok: true, resolution, result: normalized, results: [normalized] }, env, rid); return true;
  }
  return false;
}
