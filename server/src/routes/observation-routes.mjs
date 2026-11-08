export function timestampMilliseconds(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value < 100000000000 ? Math.round(value * 1000) : Math.round(value);
  const text = String(value ?? '').trim(); if (!text) return NaN;
  if (/^\d+$/.test(text)) { const numeric = Number(text); if (!Number.isFinite(numeric)) return NaN; return numeric < 100000000000 ? Math.round(numeric * 1000) : Math.round(numeric); }
  return Date.parse(text);
}

export function createObservationService(db, required) {
  function rows(userId, includeDeleted = false, cursor = NaN) {
    const values = db.prepare('SELECT id,user_id,payload,updated_at,deleted_at,version FROM observations WHERE user_id=?').all(userId);
    return values.filter(row => !Number.isFinite(cursor) || timestampMilliseconds(row.updated_at) > cursor)
      .sort((a, b) => timestampMilliseconds(b.updated_at) - timestampMilliseconds(a.updated_at)).map(row => {
        let payload = {}; try { payload = JSON.parse(row.payload); } catch { payload = { id: row.id }; }
        return { ...payload, id: row.id, userId: row.user_id, updatedAt: String(timestampMilliseconds(row.updated_at)), deleted: Boolean(row.deleted_at), version: Number(row.version || 1) };
      }).filter(item => includeDeleted || !item.deleted);
  }

  function write(userId, input, forcedId = '') {
    const id = required(forcedId || input.id, 'OBSERVATION_ID'); const inputTimestamp = timestampMilliseconds(input.updatedAt || input.createdAt);
    if (!Number.isFinite(inputTimestamp)) throw new Error('INVALID_UPDATED_AT');
    const updatedAt = String(inputTimestamp); const deleted = Boolean(input.deleted);
    const current = db.prepare('SELECT * FROM observations WHERE id=?').get(id); if (current && current.user_id !== userId) throw new Error('FORBIDDEN');
    const currentTimestamp = current ? timestampMilliseconds(current.updated_at) : NaN;
    if (current && Number.isFinite(currentTimestamp) && inputTimestamp < currentTimestamp) return { status: 'conflict', id, version: Number(current.version || 1), updatedAt: String(currentTimestamp) };
    const version = current ? Number(current.version || 1) + (inputTimestamp > currentTimestamp ? 1 : 0) : 1; const payload = { ...input, id, userId, updatedAt, deleted }; const deletedAt = deleted ? updatedAt : '';
    if (!current) db.prepare('INSERT INTO observations(id,user_id,payload,updated_at,deleted_at,version) VALUES(?,?,?,?,?,?)').run(id, userId, JSON.stringify(payload), updatedAt, deletedAt, version);
    else db.prepare('UPDATE observations SET payload=?,updated_at=?,deleted_at=?,version=? WHERE id=? AND user_id=?').run(JSON.stringify(payload), updatedAt, deletedAt, version, id, userId);
    return { status: 'applied', id, version, updatedAt };
  }
  return { rows, write };
}

export async function handleObservationRoutes(ctx) {
  const { req, res, url, env, rid, db, actor, body, json, observationRows, writeObservation } = ctx;
  if (req.method === 'GET' && url.pathname === '/api/observations') { const { userId } = actor(req); json(res, 200, observationRows(userId), env, rid); return true; }
  const observationMatch = url.pathname.match(/^\/api\/observations\/([^/]+)$/);
  if (req.method === 'PUT' && observationMatch) { const input = await body(req, 2 * 1024 * 1024); const { userId } = actor(req, input); json(res, 200, { ok: true, ...writeObservation(userId, input, observationMatch[1]) }, env, rid); return true; }
  if (req.method === 'POST' && url.pathname === '/api/sync/push') {
    const { userId } = actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const idempotencyKey = String(req.headers['idempotency-key'] || input.idempotencyKey || '').trim().slice(0, 160);
    if (idempotencyKey) { const cached = db.prepare('SELECT response_json FROM sync_operations WHERE user_id=? AND idempotency_key=?').get(userId, idempotencyKey); if (cached) { json(res, 200, JSON.parse(cached.response_json), env, rid); return true; } }
    const incoming = Array.isArray(input.mutations) ? input.mutations.map(mutation => { let parsed = {}; try { parsed = typeof mutation.payload === 'string' ? JSON.parse(mutation.payload) : (mutation.payload || {}); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); } return { ...parsed, entity: mutation.entity || 'observation', id: mutation.entityId || parsed.id, updatedAt: mutation.updatedAt || parsed.updatedAt, deleted: mutation.operation === 'delete', mutationId: mutation.mutationId }; }) : (Array.isArray(input.operations) ? input.operations : Array.isArray(input.changes) ? input.changes : Array.isArray(input.records) ? input.records : [input]);
    const rawResults = incoming.map(operation => { if (operation.entity && operation.entity !== 'observation') return { status: 'rejected', id: operation.id || '', updatedAt: '', message: '当前同步协议仅支持观察记录' }; let payload = operation.payload; if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); } } return writeObservation(userId, { ...(payload || {}), ...operation, userId }, operation.id || payload?.id); });
    const results = rawResults.map((result, index) => ({ ...result, mutationId: incoming[index].mutationId || '', entityId: result.id, result: result.status === 'applied' ? 'applied' : result.status === 'rejected' ? 'rejected' : 'conflict', serverUpdatedAt: result.updatedAt, message: result.message || (result.status === 'conflict' ? '服务器已有更新版本' : '') }));
    const response = { ok: true, results, applied: results.filter(item => item.result === 'applied').length, conflicts: results.filter(item => item.result === 'conflict').length, cursor: String(Date.now()), nextCursor: String(Date.now()) };
    if (idempotencyKey) db.prepare('INSERT OR REPLACE INTO sync_operations(idempotency_key,user_id,response_json,created_at) VALUES(?,?,?,?)').run(idempotencyKey, userId, JSON.stringify(response), Date.now());
    json(res, 200, response, env, rid); return true;
  }
  if (req.method === 'GET' && url.pathname === '/api/sync/pull') {
    const { userId } = actor(req, {}, true); const cursor = timestampMilliseconds(url.searchParams.get('cursor') || ''); const highWaterMark = Date.now(); const records = observationRows(userId, true, cursor);
    const mutations = records.map(record => ({ mutationId: `server-${record.id}-${record.version || 1}`, entity: 'observation', entityId: record.id, operation: record.deleted ? 'delete' : 'upsert', updatedAt: record.updatedAt, payload: JSON.stringify(record) }));
    json(res, 200, { ok: true, cursor: String(highWaterMark), nextCursor: String(highWaterMark), hasMore: false, records, mutations }, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/sync/resolve') {
    const { userId } = actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const resolution = String(input.resolution || 'local'); if (!['local', 'remote', 'server'].includes(resolution)) throw new Error('INVALID_RESOLUTION');
    const payload = input.local || input.server || input.payload;
    if (!payload) { const unchanged = { status: 'unchanged', result: 'unchanged', entityId: input.entityId || '' }; json(res, 200, { ok: true, resolution, result: unchanged, results: [unchanged] }, env, rid); return true; }
    const resolved = writeObservation(userId, { ...payload, userId, updatedAt: payload.updatedAt || Date.now() }, input.entityId || payload.id); const normalized = { ...resolved, result: resolved.status === 'applied' ? 'applied' : 'conflict', entityId: resolved.id, serverUpdatedAt: resolved.updatedAt, mutationId: input.mutationId || '' };
    json(res, 200, { ok: true, resolution, result: normalized, results: [normalized] }, env, rid); return true;
  }
  return false;
}
