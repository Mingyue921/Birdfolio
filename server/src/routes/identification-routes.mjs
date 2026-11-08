import { randomBytes } from 'node:crypto';
import { identifyBird } from '../identification.mjs';
import { getMedia, MAX_MEDIA_BYTES } from '../media.mjs';

function identifyStatus(result, env) {
  if (result.mode === 'provider') return 'provider_success';
  const warning = String(result.warning || '').toLowerCase();
  if (!(env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim())) return 'unavailable';
  if (warning.includes('provider 4') || warning.includes('provider 5') || warning.includes('鉴权') || warning.includes('unauthorized')) return 'provider_error';
  if (warning.includes('fetch failed') || warning.includes('timeout') || warning.includes('econn') || warning.includes('network')) return 'transport_error';
  return 'unavailable';
}

export async function handleIdentificationRoutes(ctx) {
  const { req, res, url, env, rid, db, actor, body, json, required, dataDir, requireAuthByDefault, writeObservation } = ctx;
  function authQuota(userId) { const limit = Math.max(1, Number(env.AI_DAILY_LIMIT || 10)); const since = Date.now() - 24 * 60 * 60 * 1000; const row = db.prepare('SELECT COUNT(*) AS count FROM identify_requests WHERE user_id=? AND created_at>=?').get(userId, since); if (Number(row?.count || 0) >= limit) throw new Error('QUOTA_EXCEEDED'); }
  if (req.method === 'POST' && url.pathname === '/api/identify/image') {
    const input = await body(req, Math.ceil(MAX_MEDIA_BYTES * 1.5)); const { userId, authenticated } = actor(req, input); if (requireAuthByDefault && !authenticated) throw new Error('AUTH_REQUIRED');
    let imageBase64 = String(input.imageBase64 || ''); const mediaId = String(input.mediaId || ''); if (authenticated) { authQuota(userId); if (!mediaId) throw new Error('MEDIA_REQUIRED'); }
    if (mediaId) { if (!authenticated) throw new Error('AUTH_REQUIRED'); const media = getMedia(db, dataDir, mediaId, userId); if (!media) throw new Error('MEDIA_NOT_FOUND'); imageBase64 = `data:${media.row.mime_type};base64,${media.buffer.toString('base64')}`; }
    if (!/^data:image\/(png|jpe?g|webp);base64,[A-Za-z0-9+/=\s]+$/i.test(imageBase64) || imageBase64.length > Math.ceil(MAX_MEDIA_BYTES * 1.5)) throw new Error('INVALID_IMAGE');
    const created = Date.now(); const identifyId = `identify-${created}-${randomBytes(6).toString('hex')}`; const started = Date.now(); const result = await identifyBird({ ...input, imageBase64 }, env); const elapsedMs = Date.now() - started; const status = identifyStatus(result, env);
    db.prepare(`INSERT INTO identify_requests(id,user_id,media_id,status,mode,result_json,warning,model_version,created_at,updated_at,confirmed_at) VALUES(?,?,?,?,?,?,?,?,?,?,0)`).run(identifyId, userId, mediaId, status, result.mode, JSON.stringify(result), String(result.warning || ''), String(env.VISION_MODEL || '').slice(0, 120), created, created);
    json(res, 200, { ...result, requestId: identifyId, status, mediaId, modelVersion: String(env.VISION_MODEL || ''), elapsedMs }, env, rid); return true;
  }
  const confirm = url.pathname.match(/^\/api\/identify\/([^/]+)\/confirm$/);
  if (req.method === 'POST' && confirm) { const input = await body(req, 64 * 1024); const { userId } = actor(req, {}, true); const row = db.prepare('SELECT * FROM identify_requests WHERE id=? AND user_id=?').get(confirm[1], userId); if (!row) throw new Error('IDENTIFY_NOT_FOUND'); let result; try { result = JSON.parse(row.result_json); } catch { result = {}; } const speciesId = required(input.speciesId || input.selectedSpeciesId, 'SPECIES_ID'); const candidate = (result.candidates || []).find(item => item.speciesId === speciesId); if (!candidate) throw new Error('INVALID_CANDIDATE'); const now = Date.now(); db.prepare('UPDATE identify_requests SET status=?,updated_at=?,confirmed_at=? WHERE id=?').run('user_confirmed', now, now, row.id); let observationId = ''; if (input.observation && typeof input.observation === 'object') { const observationInput = { ...input.observation, speciesId, updatedAt: input.observation.updatedAt || now }; const saved = writeObservation(userId, observationInput, input.observation.id || `observation-${now}-${randomBytes(4).toString('hex')}`); observationId = saved.id; } json(res, 200, { ok: true, confirmed: true, status: 'user_confirmed', requestId: row.id, speciesId, candidate, observationId: observationId || undefined, message: '已确认候选鸟种' }, env, rid); return true; }
  const feedback = url.pathname.match(/^\/api\/identify\/([^/]+)\/feedback$/);
  if (req.method === 'POST' && feedback) { const input = await body(req, 64 * 1024); const { userId } = actor(req, {}, true); const row = db.prepare('SELECT id FROM identify_requests WHERE id=? AND user_id=?').get(feedback[1], userId); if (!row) throw new Error('IDENTIFY_NOT_FOUND'); const id = `feedback-${Date.now()}-${randomBytes(5).toString('hex')}`; db.prepare('INSERT INTO identify_feedback(id,request_id,user_id,species_id,rating,reason,created_at) VALUES(?,?,?,?,?,?,?)').run(id, row.id, userId, String(input.speciesId || input.selectedSpeciesId || ''), String(input.rating || (input.accepted ? 'accepted' : 'rejected')).slice(0, 32), String(input.reason || input.note || '').slice(0, 1000), Date.now()); json(res, 201, { ok: true, id }, env, rid); return true; }
  return false;
}
