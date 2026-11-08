import { createServer } from 'node:http';
import { setDefaultResultOrder } from 'node:dns';
import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { basename, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes } from 'node:crypto';
import { openDatabase, postRows } from './database.mjs';
import { identifyBird } from './identification.mjs';
import { searchGbifBirds } from './gbif.mjs';
import { createAuthStore, bearerToken, LEGACY_USER_ID } from './auth.mjs';
import { decodeDataUrl, getMedia, saveMedia, sanitizeImageBuffer, validateImageBuffer, removeMediaFile, MAX_MEDIA_BYTES } from './media.mjs';

setDefaultResultOrder('ipv4first');
const root = resolve(fileURLToPath(new URL('..', import.meta.url)));

function loadEnv(path) {
  if (!existsSync(path)) return {};
  return Object.fromEntries(readFileSync(path, 'utf8').split(/\r?\n/).filter(line => line && !line.startsWith('#')).map(line => {
    const index = line.indexOf('='); return index < 0 ? [line.trim(), ''] : [line.slice(0, index).trim(), line.slice(index + 1).trim()];
  }));
}

function requestId(req) { return String(req.headers['x-request-id'] || `req-${Date.now()}-${randomBytes(4).toString('hex')}`).replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 96); }

function json(res, status, value, env = {}, id = '') {
  const origin = String(env.CORS_ORIGIN || '*').trim() || '*';
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization,idempotency-key,x-request-id',
    'x-request-id': id || `req-${Date.now()}`
  });
  res.end(JSON.stringify(value));
}

async function rawBody(req, maxBytes = 5 * 1024 * 1024) {
  const chunks = []; let size = 0;
  for await (const chunk of req) { size += chunk.length; if (size > maxBytes) throw new Error('PAYLOAD_TOO_LARGE'); chunks.push(chunk); }
  return Buffer.concat(chunks);
}

async function body(req, maxBytes = 5 * 1024 * 1024) {
  const bytes = await rawBody(req, maxBytes); if (!bytes.length) return {};
  try { return JSON.parse(bytes.toString('utf8')); } catch { throw new Error('INVALID_JSON'); }
}

function required(value, name) { const text = String(value || '').trim(); if (!text) throw new Error(`MISSING_${name}`); return text; }

function assertProductionConfig(env, host) {
  if (String(env.NODE_ENV || '').toLowerCase() !== 'production') return;
  const problems = [];
  if (String(env.REQUIRE_AUTH || '').toLowerCase() !== 'true') problems.push('REQUIRE_AUTH=true');
  const cors = String(env.CORS_ORIGIN || '').trim();
  if (!cors || cors === '*') problems.push('CORS_ORIGIN allow-list');
  if (host === '0.0.0.0' || host === '::') problems.push('HOST must be loopback behind HTTPS proxy');
  const visionUrl = String(env.VISION_API_URL || '').trim();
  if (!visionUrl || !String(env.VISION_API_KEY || '').trim() || !String(env.VISION_MODEL || '').trim()) {
    problems.push('VISION_API_URL/VISION_API_KEY/VISION_MODEL');
  } else {
    try {
      if (new URL(visionUrl).protocol !== 'https:') problems.push('VISION_API_URL=https');
    } catch (_error) { problems.push('VISION_API_URL'); }
  }
  const mailUrl = String(env.MAIL_PROVIDER_URL || '').trim();
  if (!mailUrl) problems.push('MAIL_PROVIDER_URL');
  else {
    try {
      if (new URL(mailUrl).protocol !== 'https:') problems.push('MAIL_PROVIDER_URL=https');
    } catch (_error) { problems.push('MAIL_PROVIDER_URL'); }
  }
  if (problems.length > 0) throw new Error('PRODUCTION_CONFIG_INVALID: ' + problems.join(', '));
}

async function deliverAuthCode(env, result) {
  const endpoint = String(env.MAIL_PROVIDER_URL || '').trim();
  if (!endpoint) return;
  const headers = { 'content-type': 'application/json' };
  if (String(env.MAIL_PROVIDER_TOKEN || '').trim()) headers.authorization = 'Bearer ' + String(env.MAIL_PROVIDER_TOKEN).trim();
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify({ to: result.email, code: result.deliveryCode, expiresIn: result.expiresIn }),
      signal: AbortSignal.timeout(Number(env.MAIL_PROVIDER_TIMEOUT_MS || 5000))
    });
    if (!response.ok) throw new Error('HTTP_' + response.status.toString());
  } catch (_error) {
    throw new Error('PROVIDER_UNAVAILABLE');
  }
}

export function timestampMilliseconds(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value < 100000000000 ? Math.round(value * 1000) : Math.round(value);
  const text = String(value ?? '').trim(); if (!text) return NaN;
  if (/^\d+$/.test(text)) { const numeric = Number(text); if (!Number.isFinite(numeric)) return NaN; return numeric < 100000000000 ? Math.round(numeric * 1000) : Math.round(numeric); }
  return Date.parse(text);
}

function errorStatus(message) {
  if (message === 'PAYLOAD_TOO_LARGE') return 413;
  if (['AUTH_REQUIRED', 'INVALID_TOKEN', 'INVALID_REFRESH_TOKEN'].includes(message)) return 401;
  if (['FORBIDDEN', 'ACCOUNT_DELETED'].includes(message)) return 403;
  if (message === 'NOT_FOUND' || message.endsWith('_NOT_FOUND') || message === 'MEDIA_NOT_FOUND' || message === 'IDENTIFY_NOT_FOUND') return 404;
  if (['AUTH_RATE_LIMITED', 'QUOTA_EXCEEDED', 'RATE_LIMITED'].includes(message)) return 429;
  if (message === 'EMAIL_NOT_CONFIGURED' || message === 'PROVIDER_UNAVAILABLE') return 503;
  if (message === 'CONFLICT') return 409;
  if (message.startsWith('MISSING_') || message.startsWith('INVALID_') || message === 'MEDIA_REQUIRED' || message === 'AUTH_CODE_EXPIRED' || message === 'AUTH_CODE_LOCKED') return 400;
  return 500;
}

function imageUrlData(dataDir, dataUrl, id) {
  if (!dataUrl) return '';
  const decoded = decodeDataUrl(dataUrl); const info = validateImageBuffer(decoded.buffer, decoded.mime); const sanitized = sanitizeImageBuffer(decoded.buffer, info.mime);
  const uploads = join(dataDir, 'uploads'); mkdirSync(uploads, { recursive: true });
  const extension = info.mime === 'image/png' ? 'png' : info.mime === 'image/webp' ? 'webp' : 'jpg'; const fileName = `${id}.${extension}`;
  writeFileSync(join(uploads, fileName), sanitized); return `/media/${fileName}`;
}

function setReaction(db, postId, userId, field, value) {
  const now = new Date().toISOString(); if (!db.prepare('SELECT id FROM posts WHERE id=?').get(postId)) throw new Error('POST_NOT_FOUND');
  db.prepare(`INSERT INTO reactions(post_id,user_id,liked,favorite,updated_at) VALUES(?,?,?,?,?)
    ON CONFLICT(post_id,user_id) DO UPDATE SET ${field}=?, updated_at=?`)
    .run(postId, userId, field === 'liked' && value ? 1 : 0, field === 'favorite' && value ? 1 : 0, now, value ? 1 : 0, now);
}

function normalizeVisibility(value) { const visibility = String(value || '所有人').trim(); return ['所有人', '仅自己', '好友'].includes(visibility) ? visibility : '所有人'; }

function identifyStatus(result, env) {
  if (result.mode === 'provider') return 'provider_success';
  const warning = String(result.warning || '').toLowerCase();
  if (!(env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim())) return 'unavailable';
  if (warning.includes('provider 4') || warning.includes('provider 5') || warning.includes('鉴权') || warning.includes('unauthorized')) return 'provider_error';
  if (warning.includes('fetch failed') || warning.includes('timeout') || warning.includes('econn') || warning.includes('network')) return 'transport_error';
  return 'unavailable';
}

export function createBirdfolioServer(options = {}) {
  const dataDir = resolve(options.dataDir || join(root, 'data')); mkdirSync(dataDir, { recursive: true });
  const env = { ...loadEnv(join(root, '.env')), ...process.env, ...(options.env || {}) };
  const seedDemo = String(env.DEMO_MODE ?? 'true').toLowerCase() !== 'false';
  const db = openDatabase(options.databasePath || join(dataDir, 'birdfolio.db'), { seed: seedDemo }); const auth = createAuthStore(db, { env });
  const requireAuthByDefault = String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'production';
  const speciesCatalog = options.speciesCatalog || (input => searchGbifBirds({ ...input, cachePath: join(dataDir, 'gbif-cache.json') }));
  const rateBuckets = new Map();

  function enforceRate(key, limit, windowMs) {
    const now = Date.now(); const current = rateBuckets.get(key);
    if (!current || current.startedAt + windowMs <= now) { rateBuckets.set(key, { startedAt: now, count: 1 }); return; }
    current.count += 1; if (current.count > limit) throw new Error('RATE_LIMITED');
  }

  function actor(req, input = {}, requiredAuth = requireAuthByDefault) {
    const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null;
    if (presented && !user) throw new Error('INVALID_TOKEN'); if (requiredAuth && !user) throw new Error('AUTH_REQUIRED');
    const legacyAllowed = String(env.ALLOW_LEGACY_DEMO ?? (String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' ? 'false' : 'true')).toLowerCase() !== 'false';
    if (!user && !legacyAllowed) throw new Error('AUTH_REQUIRED');
    return { user, userId: user?.id || String(input.userId || LEGACY_USER_ID), authenticated: Boolean(user) };
  }

  function authQuota(userId) {
    const limit = Math.max(1, Number(env.AI_DAILY_LIMIT || 10)); const since = Date.now() - 24 * 60 * 60 * 1000;
    const row = db.prepare('SELECT COUNT(*) AS count FROM identify_requests WHERE user_id=? AND created_at>=?').get(userId, since); if (Number(row?.count || 0) >= limit) throw new Error('QUOTA_EXCEEDED');
  }

  function observationRows(userId, includeDeleted = false, cursor = NaN) {
    const rows = db.prepare('SELECT id,user_id,payload,updated_at,deleted_at,version FROM observations WHERE user_id=?').all(userId);
    return rows.filter(row => !Number.isFinite(cursor) || timestampMilliseconds(row.updated_at) > cursor).sort((a, b) => timestampMilliseconds(b.updated_at) - timestampMilliseconds(a.updated_at)).map(row => {
      let payload = {}; try { payload = JSON.parse(row.payload); } catch { payload = { id: row.id }; }
      return { ...payload, id: row.id, userId: row.user_id, updatedAt: String(timestampMilliseconds(row.updated_at)), deleted: Boolean(row.deleted_at), version: Number(row.version || 1) };
    }).filter(item => includeDeleted || !item.deleted);
  }

  function writeObservation(userId, input, forcedId = '') {
    const id = required(forcedId || input.id, 'OBSERVATION_ID'); const inputTimestamp = timestampMilliseconds(input.updatedAt || input.createdAt);
    if (!Number.isFinite(inputTimestamp)) throw new Error('INVALID_UPDATED_AT'); const updatedAt = String(inputTimestamp); const deleted = Boolean(input.deleted);
    const current = db.prepare('SELECT * FROM observations WHERE id=?').get(id); if (current && current.user_id !== userId) throw new Error('FORBIDDEN');
    const currentTimestamp = current ? timestampMilliseconds(current.updated_at) : NaN;
    if (current && Number.isFinite(currentTimestamp) && inputTimestamp < currentTimestamp) return { status: 'conflict', id, version: Number(current.version || 1), updatedAt: String(currentTimestamp) };
    const version = current ? Number(current.version || 1) + (inputTimestamp > currentTimestamp ? 1 : 0) : 1; const payload = { ...input, id, userId, updatedAt, deleted }; const deletedAt = deleted ? updatedAt : '';
    if (!current) db.prepare('INSERT INTO observations(id,user_id,payload,updated_at,deleted_at,version) VALUES(?,?,?,?,?,?)').run(id, userId, JSON.stringify(payload), updatedAt, deletedAt, version);
    else db.prepare('UPDATE observations SET payload=?,updated_at=?,deleted_at=?,version=? WHERE id=? AND user_id=?').run(JSON.stringify(payload), updatedAt, deletedAt, version, id, userId);
    return { status: 'applied', id, version, updatedAt };
  }

  const server = createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost'); const rid = requestId(req);
    if (req.method === 'OPTIONS') { res.writeHead(204, { 'access-control-allow-origin': String(env.CORS_ORIGIN || '*'), 'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS', 'access-control-allow-headers': 'content-type,authorization,idempotency-key,x-request-id' }); res.end(); return; }
    try {
      if (req.method === 'POST' && url.pathname === '/api/auth/request-code') {
        const input = await body(req, 64 * 1024);
        const debugAllowed = String(env.AUTH_DEBUG_CODES || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'test';
        if (requireAuthByDefault && !String(env.MAIL_PROVIDER_URL || '').trim() && !debugAllowed) throw new Error('EMAIL_NOT_CONFIGURED');
        const result = auth.requestCode(input.email, req.socket.remoteAddress || '');
        await deliverAuthCode(env, result);
        const response = { ok: true, accepted: true, email: result.email, expiresIn: result.expiresIn, expiresInSeconds: result.expiresIn, retryAfterSeconds: 60, message: String(env.MAIL_PROVIDER_URL || '').trim() ? '验证码已发送' : '开发模式验证码已生成', delivery: String(env.MAIL_PROVIDER_URL || '').trim() ? 'email' : 'development' };
        if (result.debugCode) response.debugCode = result.debugCode;
        return json(res, 200, response, env, rid);
      }
      if (req.method === 'POST' && url.pathname === '/api/auth/verify-code') { const input = await body(req, 64 * 1024); return json(res, 200, auth.verifyCode(input.email, input.code), env, rid); }
      if (req.method === 'POST' && url.pathname === '/api/auth/refresh') { const input = await body(req, 64 * 1024); return json(res, 200, auth.refresh(input.refreshToken), env, rid); }
      if (req.method === 'POST' && url.pathname === '/api/auth/logout') { const input = await body(req, 64 * 1024); auth.revokeAccess(bearerToken(req)); auth.revokeRefresh(input.refreshToken); return json(res, 200, { ok: true }, env, rid); }
      if (req.method === 'GET' && url.pathname === '/api/me') { const { user } = actor(req, {}, true); const safeUser = user ? { id: user.id, email: user.email, displayName: user.displayName, createdAt: user.createdAt, updatedAt: user.updatedAt } : null; return json(res, 200, { ...(safeUser || {}), user: safeUser }, env, rid); }
      if (req.method === 'POST' && url.pathname === '/api/account/export') {
        const { userId } = actor(req, {}, true); const generatedAt = new Date().toISOString(); const bundle = { exportedAt: generatedAt, userId, observations: observationRows(userId, true), posts: postRows(db, 'WHERE p.user_id=?', [userId], userId), comments: db.prepare('SELECT id,post_id,body,created_at FROM comments WHERE user_id=? ORDER BY created_at').all(userId) }; return json(res, 200, { format: 'birdfolio-json', generatedAt, payload: JSON.stringify(bundle), ...bundle }, env, rid);
      }
      if (req.method === 'DELETE' && url.pathname === '/api/account') {
        const { userId } = actor(req, {}, true); const mediaRows = db.prepare('SELECT * FROM media WHERE user_id=?').all(userId); const postFiles = db.prepare('SELECT image_url FROM posts WHERE user_id=? AND image_url<>\'\'').all(userId); db.exec('BEGIN');
        try { db.prepare('DELETE FROM comments WHERE user_id=?').run(userId); db.prepare('DELETE FROM reactions WHERE user_id=?').run(userId); db.prepare('DELETE FROM content_reports WHERE reporter_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(userId, userId); db.prepare('DELETE FROM posts WHERE user_id=?').run(userId); db.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_user_id=?').run(userId, userId); db.prepare('DELETE FROM identify_feedback WHERE user_id=?').run(userId); db.prepare('DELETE FROM identify_requests WHERE user_id=?').run(userId); db.prepare('DELETE FROM observations WHERE user_id=?').run(userId); db.prepare('DELETE FROM media WHERE user_id=?').run(userId); db.prepare('DELETE FROM sync_operations WHERE user_id=?').run(userId); db.prepare('DELETE FROM auth_codes WHERE email=(SELECT email FROM users WHERE id=?)').run(userId); db.prepare('UPDATE users SET deleted_at=?,updated_at=? WHERE id=?').run(Date.now(), new Date().toISOString(), userId); auth.revokeUser(userId); db.exec('COMMIT'); } catch (error) { db.exec('ROLLBACK'); throw error; }
        mediaRows.forEach(removeMediaFile); postFiles.forEach(item => { if (item.image_url?.startsWith('/media/')) { const path = join(dataDir, 'uploads', basename(item.image_url)); if (existsSync(path)) { try { unlinkSync(path); } catch { /* best effort */ } } } }); return json(res, 200, { ok: true }, env, rid);
      }
      if (req.method === 'GET' && url.pathname === '/api/health') return json(res, 200, { ok: true, service: 'birdfolio', aiMode: env.VISION_API_URL?.trim() && env.VISION_API_KEY?.trim() && env.VISION_MODEL?.trim() ? 'provider' : 'unavailable', auth: 'email_code', version: 'beta-1' }, env, rid);
      if (req.method === 'GET' && url.pathname === '/api/species') { const query = url.searchParams.get('q') || ''; const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); return json(res, 200, await speciesCatalog({ query, limit }), env, rid); }

      if (req.method === 'GET' && url.pathname === '/api/posts') {
        const { userId } = actor(req); const mode = url.searchParams.get('mode'); let where = "WHERE (p.visibility='所有人' OR p.user_id=?) AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id=? AND b.blocked_user_id=p.user_id)"; let params = [userId, userId];
        if (mode === '关注') { where += ' AND p.user_id IN (?,?)'; params.push(userId, 'forest-letter'); } if (mode === '附近') where += " AND p.place_name<>''";
        const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); const offset = Math.max(0, Number(url.searchParams.get('offset') || 0));
        return json(res, 200, postRows(db, where, params, userId).slice(offset, offset + limit), env, rid);
      }
      if (req.method === 'POST' && url.pathname === '/api/posts') {
        const input = await body(req); const { user, userId } = actor(req, input); enforceRate(`post:${userId}`, 20, 60 * 1000); const id = `post-${Date.now()}-${Math.floor(Math.random() * 10000)}`; const now = new Date().toISOString(); let imageUrl = '';
        if (input.mediaId) { if (!user) throw new Error('AUTH_REQUIRED'); const media = db.prepare('SELECT * FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(input.mediaId, userId); if (!media) throw new Error('MEDIA_NOT_FOUND'); db.prepare('UPDATE media SET expires_at=? WHERE id=?').run(Date.now() + 365 * 24 * 60 * 60 * 1000, media.id); imageUrl = `/media/${media.file_name}`; } else if (input.imageBase64) imageUrl = imageUrlData(dataDir, input.imageBase64, id);
        const title = required(input.title, 'TITLE'); const postBody = required(input.body, 'BODY'); if (title.length > 120 || postBody.length > 10000) throw new Error('INVALID_TEXT_LENGTH'); const authorName = user?.displayName || input.authorName || '林中客';
        db.prepare(`INSERT INTO posts(id,user_id,author_name,type,title,body,species_id,behavior,place_name,visibility,image_url,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(id, userId, authorName, input.type === 'journal' ? 'journal' : 'photo', title, postBody, String(input.speciesId || '').slice(0, 120), String(input.behavior || '').slice(0, 120), String(input.placeName || '').slice(0, 200), normalizeVisibility(input.visibility), imageUrl, now, now);
        return json(res, 201, postRows(db, 'WHERE p.id=?', [id], userId)[0], env, rid);
      }
      const postMatch = url.pathname.match(/^\/api\/posts\/([^/]+)$/);
      if (req.method === 'GET' && postMatch) { const { userId } = actor(req); const rows = postRows(db, 'WHERE p.id=? AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id=? AND b.blocked_user_id=p.user_id)', [postMatch[1], userId], userId); return rows.length && (rows[0].visibility === '所有人' || rows[0].userId === userId) ? json(res, 200, rows[0], env, rid) : json(res, 404, { error: 'POST_NOT_FOUND' }, env, rid); }
      if (req.method === 'DELETE' && postMatch) { const { userId } = actor(req, {}, true); const post = db.prepare('SELECT id,user_id,image_url FROM posts WHERE id=?').get(postMatch[1]); if (!post) throw new Error('POST_NOT_FOUND'); if (post.user_id !== userId) throw new Error('FORBIDDEN'); db.prepare('DELETE FROM posts WHERE id=?').run(post.id); if (post.image_url?.startsWith('/media/')) { const imagePath = join(dataDir, 'uploads', basename(post.image_url)); if (existsSync(imagePath)) { try { unlinkSync(imagePath); } catch { /* best effort */ } } } return json(res, 200, { ok: true, id: post.id }, env, rid); }
      const reactionMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/(like|favorite)$/);
      if (req.method === 'POST' && reactionMatch) { const input = await body(req, 64 * 1024); const { userId } = actor(req, input); const post = db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(reactionMatch[1]); if (!post || (post.visibility !== '所有人' && post.user_id !== userId) || db.prepare('SELECT 1 AS blocked FROM user_blocks WHERE blocker_id=? AND blocked_user_id=?').get(userId, post.user_id)) throw new Error('POST_NOT_FOUND'); setReaction(db, reactionMatch[1], userId, reactionMatch[2] === 'like' ? 'liked' : 'favorite', input.value !== false); return json(res, 200, postRows(db, 'WHERE p.id=?', [reactionMatch[1]], userId)[0], env, rid); }
      const commentsMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/comments$/);
      if (commentsMatch && req.method === 'GET') { const { userId } = actor(req); const post = db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(commentsMatch[1]); if (!post) throw new Error('POST_NOT_FOUND'); if (post.visibility !== '所有人' && post.user_id !== userId) throw new Error('POST_NOT_FOUND'); const rows = db.prepare('SELECT id,post_id,user_id,author_name,body,created_at FROM comments WHERE post_id=? ORDER BY created_at ASC').all(commentsMatch[1]); return json(res, 200, rows.map(row => ({ id: row.id, postId: row.post_id, userId: row.user_id, authorName: row.author_name, body: row.body, createdAt: row.created_at })), env, rid); }
      if (commentsMatch && req.method === 'POST') { const input = await body(req, 128 * 1024); const { user, userId } = actor(req, input); enforceRate(`comment:${userId}`, 60, 60 * 1000); const id = `comment-${Date.now()}-${Math.floor(Math.random() * 10000)}`; const now = new Date().toISOString(); const post = db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(commentsMatch[1]); if (!post || (post.visibility !== '所有人' && post.user_id !== userId) || db.prepare('SELECT 1 AS blocked FROM user_blocks WHERE blocker_id=? AND blocked_user_id=?').get(userId, post.user_id)) throw new Error('POST_NOT_FOUND'); const commentBody = required(input.body, 'BODY'); if (commentBody.length > 2000) throw new Error('INVALID_TEXT_LENGTH'); const authorName = user?.displayName || input.authorName || '林中客'; db.prepare('INSERT INTO comments(id,post_id,user_id,author_name,body,created_at) VALUES(?,?,?,?,?,?)').run(id, commentsMatch[1], userId, authorName, commentBody, now); return json(res, 201, { id, postId: commentsMatch[1], userId, authorName, body: commentBody, createdAt: now }, env, rid); }
      const reportMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/report$/);
      if (req.method === 'POST' && reportMatch) { const input = await body(req, 64 * 1024); const { userId } = actor(req, {}, true); if (!db.prepare('SELECT id FROM posts WHERE id=?').get(reportMatch[1])) throw new Error('POST_NOT_FOUND'); const id = `report-${Date.now()}-${randomBytes(5).toString('hex')}`; const reason = required(input.reason || '未说明', 'REASON'); if (reason.length > 1000) throw new Error('INVALID_TEXT_LENGTH'); db.prepare('INSERT INTO content_reports(id,reporter_id,post_id,reason,status,created_at) VALUES(?,?,?,?,?,?)').run(id, userId, reportMatch[1], reason, 'open', Date.now()); return json(res, 201, { ok: true, id, status: 'open' }, env, rid); }
      const blockMatch = url.pathname.match(/^\/api\/users\/([^/]+)\/block$/);
      if (req.method === 'POST' && blockMatch) { const { userId } = actor(req, {}, true); if (blockMatch[1] === userId) throw new Error('INVALID_BLOCK_TARGET'); db.prepare('INSERT OR IGNORE INTO user_blocks(blocker_id,blocked_user_id,created_at) VALUES(?,?,?)').run(userId, blockMatch[1], Date.now()); return json(res, 200, { ok: true, blockedUserId: blockMatch[1] }, env, rid); }

      if (req.method === 'GET' && url.pathname === '/api/observations') { const { userId } = actor(req); return json(res, 200, observationRows(userId), env, rid); }
      const observationMatch = url.pathname.match(/^\/api\/observations\/([^/]+)$/);
      if (req.method === 'PUT' && observationMatch) { const input = await body(req, 2 * 1024 * 1024); const { userId } = actor(req, input); return json(res, 200, { ok: true, ...writeObservation(userId, input, observationMatch[1]) }, env, rid); }

      if (req.method === 'POST' && url.pathname === '/api/media') {
        const { userId } = actor(req, {}, true); enforceRate(`media:${userId}`, 20, 60 * 60 * 1000); const contentType = String(req.headers['content-type'] || '').toLowerCase(); let buffer; let mime = '';
        if (contentType.includes('application/json')) { const input = await body(req, Math.ceil(MAX_MEDIA_BYTES * 1.5)); const decoded = decodeDataUrl(input.dataBase64 || input.dataUrl || input.imageBase64); buffer = decoded.buffer; mime = decoded.mime; } else { buffer = await rawBody(req, MAX_MEDIA_BYTES + 1); mime = contentType.split(';')[0].trim(); }
        const result = saveMedia({ dataDir, db, userId, buffer, mime, ttlMs: Number(env.MEDIA_TTL_MS || 60 * 60 * 1000) }); return json(res, 201, { ok: true, mediaId: result.id, ...result, sizeBytes: result.byteSize, path: result.url }, env, rid);
      }
      const mediaApiMatch = url.pathname.match(/^\/api\/media\/([^/]+)$/);
      if (req.method === 'GET' && mediaApiMatch) { const { userId } = actor(req, {}, true); const row = db.prepare('SELECT id,mime_type,byte_size,created_at,expires_at FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(mediaApiMatch[1], userId); if (!row) throw new Error('MEDIA_NOT_FOUND'); return json(res, 200, { ...row, mediaId: row.id }, env, rid); }

      if (req.method === 'POST' && url.pathname === '/api/identify/image') {
        const input = await body(req, Math.ceil(MAX_MEDIA_BYTES * 1.5)); const { userId, authenticated } = actor(req, input);
        if (requireAuthByDefault && !authenticated) throw new Error('AUTH_REQUIRED');
        let imageBase64 = String(input.imageBase64 || ''); let mediaId = String(input.mediaId || '');
        if (authenticated) { authQuota(userId); if (!mediaId) throw new Error('MEDIA_REQUIRED'); }
        if (mediaId) { if (!authenticated) throw new Error('AUTH_REQUIRED'); const media = getMedia(db, dataDir, mediaId, userId); if (!media) throw new Error('MEDIA_NOT_FOUND'); imageBase64 = `data:${media.row.mime_type};base64,${media.buffer.toString('base64')}`; }
        if (!/^data:image\/(png|jpe?g|webp);base64,[A-Za-z0-9+/=\s]+$/i.test(imageBase64) || imageBase64.length > Math.ceil(MAX_MEDIA_BYTES * 1.5)) throw new Error('INVALID_IMAGE');
        const created = Date.now(); const identifyId = `identify-${created}-${randomBytes(6).toString('hex')}`; const started = Date.now(); const result = await identifyBird({ ...input, imageBase64 }, env); const elapsedMs = Date.now() - started; const status = identifyStatus(result, env);
        db.prepare(`INSERT INTO identify_requests(id,user_id,media_id,status,mode,result_json,warning,model_version,created_at,updated_at,confirmed_at) VALUES(?,?,?,?,?,?,?,?,?,?,0)`).run(identifyId, userId, mediaId, status, result.mode, JSON.stringify(result), String(result.warning || ''), String(env.VISION_MODEL || '').slice(0, 120), created, created);
        return json(res, 200, { ...result, requestId: identifyId, status, mediaId, modelVersion: String(env.VISION_MODEL || ''), elapsedMs }, env, rid);
      }
      const identifyConfirm = url.pathname.match(/^\/api\/identify\/([^/]+)\/confirm$/);
      if (req.method === 'POST' && identifyConfirm) { const input = await body(req, 64 * 1024); const { userId } = actor(req, {}, true); const row = db.prepare('SELECT * FROM identify_requests WHERE id=? AND user_id=?').get(identifyConfirm[1], userId); if (!row) throw new Error('IDENTIFY_NOT_FOUND'); let result; try { result = JSON.parse(row.result_json); } catch { result = {}; } const speciesId = required(input.speciesId || input.selectedSpeciesId, 'SPECIES_ID'); const candidate = (result.candidates || []).find(item => item.speciesId === speciesId); if (!candidate) throw new Error('INVALID_CANDIDATE'); const now = Date.now(); db.prepare('UPDATE identify_requests SET status=?,updated_at=?,confirmed_at=? WHERE id=?').run('user_confirmed', now, now, row.id); let observationId = ''; if (input.observation && typeof input.observation === 'object') { const observationInput = { ...input.observation, speciesId, updatedAt: input.observation.updatedAt || now }; const saved = writeObservation(userId, observationInput, input.observation.id || `observation-${now}-${randomBytes(4).toString('hex')}`); observationId = saved.id; } return json(res, 200, { ok: true, confirmed: true, status: 'user_confirmed', requestId: row.id, speciesId, candidate, observationId: observationId || undefined, message: '已确认候选鸟种' }, env, rid); }
      const identifyFeedback = url.pathname.match(/^\/api\/identify\/([^/]+)\/feedback$/);
      if (req.method === 'POST' && identifyFeedback) { const input = await body(req, 64 * 1024); const { userId } = actor(req, {}, true); const row = db.prepare('SELECT id FROM identify_requests WHERE id=? AND user_id=?').get(identifyFeedback[1], userId); if (!row) throw new Error('IDENTIFY_NOT_FOUND'); const id = `feedback-${Date.now()}-${randomBytes(5).toString('hex')}`; db.prepare('INSERT INTO identify_feedback(id,request_id,user_id,species_id,rating,reason,created_at) VALUES(?,?,?,?,?,?,?)').run(id, row.id, userId, String(input.speciesId || input.selectedSpeciesId || ''), String(input.rating || (input.accepted ? 'accepted' : 'rejected')).slice(0, 32), String(input.reason || input.note || '').slice(0, 1000), Date.now()); return json(res, 201, { ok: true, id }, env, rid); }

      if (req.method === 'POST' && url.pathname === '/api/sync/push') {
        const { userId } = actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const idempotencyKey = String(req.headers['idempotency-key'] || input.idempotencyKey || '').trim().slice(0, 160);
        if (idempotencyKey) { const cached = db.prepare('SELECT response_json FROM sync_operations WHERE user_id=? AND idempotency_key=?').get(userId, idempotencyKey); if (cached) return json(res, 200, JSON.parse(cached.response_json), env, rid); }
        const incoming = Array.isArray(input.mutations) ? input.mutations.map(mutation => {
          let parsed = {}; try { parsed = typeof mutation.payload === 'string' ? JSON.parse(mutation.payload) : (mutation.payload || {}); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); }
          return { ...parsed, entity: mutation.entity || 'observation', id: mutation.entityId || parsed.id, updatedAt: mutation.updatedAt || parsed.updatedAt, deleted: mutation.operation === 'delete', mutationId: mutation.mutationId };
        }) : (Array.isArray(input.operations) ? input.operations : Array.isArray(input.changes) ? input.changes : Array.isArray(input.records) ? input.records : [input]);
        const rawResults = incoming.map(operation => {
          if (operation.entity && operation.entity !== 'observation') return { status: 'rejected', id: operation.id || '', updatedAt: '', message: '当前同步协议仅支持观察记录' };
          let payload = operation.payload; if (typeof payload === 'string') { try { payload = JSON.parse(payload); } catch { throw new Error('INVALID_SYNC_PAYLOAD'); } }
          return writeObservation(userId, { ...(payload || {}), ...operation, userId }, operation.id || payload?.id);
        });
        const results = rawResults.map((result, index) => ({ ...result, mutationId: incoming[index].mutationId || '', entityId: result.id, result: result.status === 'applied' ? 'applied' : result.status === 'rejected' ? 'rejected' : 'conflict', serverUpdatedAt: result.updatedAt, message: result.message || (result.status === 'conflict' ? '服务器已有更新版本' : '') }));
        const response = { ok: true, results, applied: results.filter(item => item.result === 'applied').length, conflicts: results.filter(item => item.result === 'conflict').length, cursor: String(Date.now()), nextCursor: String(Date.now()) };
        if (idempotencyKey) db.prepare('INSERT OR REPLACE INTO sync_operations(idempotency_key,user_id,response_json,created_at) VALUES(?,?,?,?)').run(idempotencyKey, userId, JSON.stringify(response), Date.now()); return json(res, 200, response, env, rid);
      }
      if (req.method === 'GET' && url.pathname === '/api/sync/pull') {
        const { userId } = actor(req, {}, true); const cursor = timestampMilliseconds(url.searchParams.get('cursor') || '');
        // Take the high-water mark before reading. Writes that race this query
        // have a later timestamp and will be picked up by the next pull.
        const highWaterMark = Date.now(); const records = observationRows(userId, true, cursor);
        const mutations = records.map(record => ({ mutationId: `server-${record.id}-${record.version || 1}`, entity: 'observation', entityId: record.id, operation: record.deleted ? 'delete' : 'upsert', updatedAt: record.updatedAt, payload: JSON.stringify(record) }));
        return json(res, 200, { ok: true, cursor: String(highWaterMark), nextCursor: String(highWaterMark), hasMore: false, records, mutations }, env, rid);
      }
      if (req.method === 'POST' && url.pathname === '/api/sync/resolve') {
        const { userId } = actor(req, {}, true); const input = await body(req, 2 * 1024 * 1024); const resolution = String(input.resolution || 'local'); if (!['local', 'remote', 'server'].includes(resolution)) throw new Error('INVALID_RESOLUTION');
        const payload = input.local || input.server || input.payload; if (!payload) { const unchanged = { status: 'unchanged', result: 'unchanged', entityId: input.entityId || '' }; return json(res, 200, { ok: true, resolution, result: unchanged, results: [unchanged] }, env, rid); }
        const resolved = writeObservation(userId, { ...payload, userId, updatedAt: payload.updatedAt || Date.now() }, input.entityId || payload.id); const normalized = { ...resolved, result: resolved.status === 'applied' ? 'applied' : 'conflict', entityId: resolved.id, serverUpdatedAt: resolved.updatedAt, mutationId: input.mutationId || '' };
        return json(res, 200, { ok: true, resolution, result: normalized, results: [normalized] }, env, rid);
      }

      const mediaMatch = url.pathname.match(/^\/media\/([^/]+)$/);
      if (req.method === 'GET' && mediaMatch) {
        const fileName = basename(mediaMatch[1]); const path = join(dataDir, 'uploads', fileName); if (!existsSync(path)) return json(res, 404, { error: 'NOT_FOUND' }, env, rid);
        if (fileName.startsWith('media-')) { const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null; const row = db.prepare('SELECT user_id,mime_type,expires_at,deleted_at FROM media WHERE file_name=?').get(fileName); if (!row || row.deleted_at || row.expires_at <= Date.now()) return json(res, 404, { error: 'NOT_FOUND' }, env, rid); const publicPost = db.prepare("SELECT 1 AS visible FROM posts WHERE image_url=? AND visibility='所有人' LIMIT 1").get(`/media/${fileName}`); if ((!user || user.id !== row.user_id) && !publicPost) return json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid); res.writeHead(200, { 'content-type': row.mime_type, 'cache-control': publicPost ? 'public, max-age=300' : 'private, max-age=300' }); res.end(readFileSync(path)); return; }
        if (fileName.startsWith('post-')) {
          const post = db.prepare('SELECT user_id,visibility FROM posts WHERE image_url=?').get(`/media/${fileName}`);
          if (!post) return json(res, 404, { error: 'NOT_FOUND' }, env, rid);
          if (post && post.visibility !== '所有人') {
            const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null;
            if (!user || user.id !== post.user_id) return json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid);
          }
        }
        const extension = extname(fileName).toLowerCase(); res.writeHead(200, { 'content-type': extension === '.png' ? 'image/png' : extension === '.webp' ? 'image/webp' : 'image/jpeg' }); res.end(readFileSync(path)); return;
      }
      return json(res, 404, { error: 'NOT_FOUND' }, env, rid);
    } catch (error) { const message = String(error?.message || error); return json(res, errorStatus(message), { error: message, requestId: rid }, env, rid); }
  });
  server.on('close', () => db.close()); return server;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const env = { ...loadEnv(join(root, '.env')), ...process.env };
  const port = Number(env.PORT || 8787);
  const production = process.argv.includes('--release') || String(env.NODE_ENV || '').toLowerCase() === 'production';
  if (production) env.NODE_ENV = 'production';
  const host = env.HOST || (production ? '127.0.0.1' : '0.0.0.0');
  assertProductionConfig(env, host);
  createBirdfolioServer({ env }).listen(port, host, () => console.log(`Birdfolio server: http://${host}:${port}`));
}
