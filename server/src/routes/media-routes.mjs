import { basename, extname } from 'node:path';
import { bearerToken } from '../auth.mjs';
import { corsHeaders } from '../http.mjs';
import { decodeDataUrl, MAX_MEDIA_BYTES, saveMedia } from '../media.mjs';

export async function handleMediaRoutes(ctx) {
  const { req, res, url, env, rid, db, auth, actor, body, rawBody, json, enforceRate, mediaStorage } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/media') {
    const { userId } = await actor(req, {}, true); await enforceRate(`media:${userId}`, 20, 60 * 60 * 1000);
    const contentType = String(req.headers['content-type'] || '').toLowerCase(); let buffer; let mime = '';
    if (contentType.includes('application/json')) { const input = await body(req, Math.ceil(MAX_MEDIA_BYTES * 1.5)); const decoded = decodeDataUrl(input.dataBase64 || input.dataUrl || input.imageBase64); buffer = decoded.buffer; mime = decoded.mime; }
    else { buffer = await rawBody(req, MAX_MEDIA_BYTES + 1); mime = contentType.split(';')[0].trim(); }
    const result = await saveMedia({ storage: mediaStorage, db, userId, buffer, mime, ttlMs: Number(env.MEDIA_TTL_MS || 60 * 60 * 1000) });
    json(res, 201, { ok: true, mediaId: result.id, ...result, sizeBytes: result.byteSize, path: result.url }, env, rid); return true;
  }
  const mediaApiMatch = url.pathname.match(/^\/api\/media\/([^/]+)$/);
  if (req.method === 'GET' && mediaApiMatch) { const { userId } = await actor(req, {}, true); const row = await db.prepare('SELECT id,mime_type,byte_size,created_at,expires_at FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(mediaApiMatch[1], userId); if (!row) throw new Error('MEDIA_NOT_FOUND'); json(res, 200, { ...row, mediaId: row.id }, env, rid); return true; }

  const mediaMatch = url.pathname.match(/^\/media\/([^/]+)$/);
  if (req.method !== 'GET' || !mediaMatch) return false;
  const fileName = basename(mediaMatch[1]);
  if (fileName.startsWith('media-')) {
    const presented = bearerToken(req); const user = presented ? await auth.authenticateToken(presented) : null;
    const row = await db.prepare('SELECT user_id,mime_type,expires_at,deleted_at FROM media WHERE file_name=?').get(fileName);
    if (!row || row.deleted_at || row.expires_at <= Date.now()) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
    const publicPost = await db.prepare("SELECT 1 AS visible FROM posts WHERE image_url=? AND visibility='所有人' LIMIT 1").get(`/media/${fileName}`);
    if ((!user || user.id !== row.user_id) && !publicPost) { json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid); return true; }
    const buffer = await mediaStorage.getObject(fileName); if (!buffer) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
    res.writeHead(200, { ...corsHeaders(env), 'content-type': row.mime_type, 'cache-control': publicPost ? 'public, max-age=300' : 'private, max-age=300' }); res.end(buffer); return true;
  }
  if (fileName.startsWith('post-')) {
    const post = await db.prepare('SELECT user_id,visibility FROM posts WHERE image_url=?').get(`/media/${fileName}`);
    if (!post) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
    if (post.visibility !== '所有人') { const presented = bearerToken(req); const user = presented ? await auth.authenticateToken(presented) : null; if (!user || user.id !== post.user_id) { json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid); return true; } }
  }
  const extension = extname(fileName).toLowerCase();
  const buffer = await mediaStorage.getObject(fileName); if (!buffer) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
  res.writeHead(200, { ...corsHeaders(env), 'content-type': extension === '.png' ? 'image/png' : extension === '.webp' ? 'image/webp' : 'image/jpeg' }); res.end(buffer); return true;
}
