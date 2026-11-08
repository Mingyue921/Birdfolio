import { existsSync, readFileSync } from 'node:fs';
import { basename, extname, join } from 'node:path';
import { bearerToken } from '../auth.mjs';
import { decodeDataUrl, MAX_MEDIA_BYTES, saveMedia } from '../media.mjs';

export async function handleMediaRoutes(ctx) {
  const { req, res, url, env, rid, db, auth, actor, body, rawBody, json, enforceRate, dataDir } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/media') {
    const { userId } = actor(req, {}, true); enforceRate(`media:${userId}`, 20, 60 * 60 * 1000);
    const contentType = String(req.headers['content-type'] || '').toLowerCase(); let buffer; let mime = '';
    if (contentType.includes('application/json')) { const input = await body(req, Math.ceil(MAX_MEDIA_BYTES * 1.5)); const decoded = decodeDataUrl(input.dataBase64 || input.dataUrl || input.imageBase64); buffer = decoded.buffer; mime = decoded.mime; }
    else { buffer = await rawBody(req, MAX_MEDIA_BYTES + 1); mime = contentType.split(';')[0].trim(); }
    const result = saveMedia({ dataDir, db, userId, buffer, mime, ttlMs: Number(env.MEDIA_TTL_MS || 60 * 60 * 1000) });
    json(res, 201, { ok: true, mediaId: result.id, ...result, sizeBytes: result.byteSize, path: result.url }, env, rid); return true;
  }
  const mediaApiMatch = url.pathname.match(/^\/api\/media\/([^/]+)$/);
  if (req.method === 'GET' && mediaApiMatch) { const { userId } = actor(req, {}, true); const row = db.prepare('SELECT id,mime_type,byte_size,created_at,expires_at FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(mediaApiMatch[1], userId); if (!row) throw new Error('MEDIA_NOT_FOUND'); json(res, 200, { ...row, mediaId: row.id }, env, rid); return true; }

  const mediaMatch = url.pathname.match(/^\/media\/([^/]+)$/);
  if (req.method !== 'GET' || !mediaMatch) return false;
  const fileName = basename(mediaMatch[1]); const path = join(dataDir, 'uploads', fileName);
  if (!existsSync(path)) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
  if (fileName.startsWith('media-')) {
    const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null;
    const row = db.prepare('SELECT user_id,mime_type,expires_at,deleted_at FROM media WHERE file_name=?').get(fileName);
    if (!row || row.deleted_at || row.expires_at <= Date.now()) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
    const publicPost = db.prepare("SELECT 1 AS visible FROM posts WHERE image_url=? AND visibility='所有人' LIMIT 1").get(`/media/${fileName}`);
    if ((!user || user.id !== row.user_id) && !publicPost) { json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid); return true; }
    res.writeHead(200, { 'content-type': row.mime_type, 'cache-control': publicPost ? 'public, max-age=300' : 'private, max-age=300' }); res.end(readFileSync(path)); return true;
  }
  if (fileName.startsWith('post-')) {
    const post = db.prepare('SELECT user_id,visibility FROM posts WHERE image_url=?').get(`/media/${fileName}`);
    if (!post) { json(res, 404, { error: 'NOT_FOUND' }, env, rid); return true; }
    if (post.visibility !== '所有人') { const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null; if (!user || user.id !== post.user_id) { json(res, 401, { error: 'AUTH_REQUIRED' }, env, rid); return true; } }
  }
  const extension = extname(fileName).toLowerCase();
  res.writeHead(200, { 'content-type': extension === '.png' ? 'image/png' : extension === '.webp' ? 'image/webp' : 'image/jpeg' }); res.end(readFileSync(path)); return true;
}
