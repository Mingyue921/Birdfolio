export function timestampMilliseconds(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value < 100000000000 ? Math.round(value * 1000) : Math.round(value);
  const text = String(value ?? '').trim(); if (!text) return NaN;
  if (/^\d+$/.test(text)) { const numeric = Number(text); if (!Number.isFinite(numeric)) return NaN; return numeric < 100000000000 ? Math.round(numeric * 1000) : Math.round(numeric); }
  return Date.parse(text);
}

export function createObservationService(db, required) {
  function rows(userId, includeDeleted = false, cursor = NaN) {
    const values = db.prepare('SELECT id,user_id,payload,updated_at,deleted_at,version FROM observations WHERE user_id=?').all(userId);
    return values.filter(row => !Number.isFinite(cursor) || timestampMilliseconds(row.updated_at) > cursor).sort((a, b) => timestampMilliseconds(b.updated_at) - timestampMilliseconds(a.updated_at)).map(row => {
      let payload = {}; try { payload = JSON.parse(row.payload); } catch { payload = { id: row.id }; }
      return { ...payload, id: row.id, userId: row.user_id, updatedAt: String(timestampMilliseconds(row.updated_at)), deleted: Boolean(row.deleted_at), version: Number(row.version || 1) };
    }).filter(item => includeDeleted || !item.deleted);
  }
  function write(userId, input, forcedId = '') {
    const id = required(forcedId || input.id, 'OBSERVATION_ID'); const inputTimestamp = timestampMilliseconds(input.updatedAt || input.createdAt);
    if (!Number.isFinite(inputTimestamp)) throw new Error('INVALID_UPDATED_AT'); const updatedAt = String(inputTimestamp); const deleted = Boolean(input.deleted);
    const current = db.prepare('SELECT * FROM observations WHERE id=?').get(id); if (current && current.user_id !== userId) throw new Error('FORBIDDEN'); const currentTimestamp = current ? timestampMilliseconds(current.updated_at) : NaN;
    if (current && Number.isFinite(currentTimestamp) && inputTimestamp < currentTimestamp) return { status: 'conflict', id, version: Number(current.version || 1), updatedAt: String(currentTimestamp) };
    const version = current ? Number(current.version || 1) + (inputTimestamp > currentTimestamp ? 1 : 0) : 1; const payload = { ...input, id, userId, updatedAt, deleted }; const deletedAt = deleted ? updatedAt : '';
    if (!current) db.prepare('INSERT INTO observations(id,user_id,payload,updated_at,deleted_at,version) VALUES(?,?,?,?,?,?)').run(id, userId, JSON.stringify(payload), updatedAt, deletedAt, version); else db.prepare('UPDATE observations SET payload=?,updated_at=?,deleted_at=?,version=? WHERE id=? AND user_id=?').run(JSON.stringify(payload), updatedAt, deletedAt, version, id, userId);
    return { status: 'applied', id, version, updatedAt };
  }
  return { rows, write };
}

export async function handleObservationRoutes(ctx) {
  const { req, res, url, env, rid, actor, body, json, observationRows, writeObservation } = ctx;
  if (req.method === 'GET' && url.pathname === '/api/observations') { const { userId } = actor(req); json(res, 200, observationRows(userId), env, rid); return true; }
  const match = url.pathname.match(/^\/api\/observations\/([^/]+)$/);
  if (req.method === 'PUT' && match) { const input = await body(req, 2 * 1024 * 1024); const { userId } = actor(req, input); json(res, 200, { ok: true, ...writeObservation(userId, input, match[1]) }, env, rid); return true; }
  return false;
}
