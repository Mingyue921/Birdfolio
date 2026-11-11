import { randomBytes } from 'node:crypto';
import { postRows } from '../database.mjs';
import { decodeDataUrl, removeStoredMedia, saveMedia } from '../media.mjs';
import { protectCommunityLocation } from '../privacy/location-policy.mjs';

async function setReaction(db, postId, userId, field, value) {
  const now = new Date().toISOString(); if (!await db.prepare('SELECT id FROM posts WHERE id=?').get(postId)) throw new Error('POST_NOT_FOUND');
  await db.prepare(`INSERT INTO reactions(post_id,user_id,liked,favorite,updated_at) VALUES(?,?,?,?,?)
    ON CONFLICT(post_id,user_id) DO UPDATE SET ${field}=?, updated_at=?`)
    .run(postId, userId, field === 'liked' && value ? 1 : 0, field === 'favorite' && value ? 1 : 0, now, value ? 1 : 0, now);
}

function normalizeVisibility(value) { const visibility = String(value || '所有人').trim(); return ['所有人', '仅自己', '好友'].includes(visibility) ? visibility : '所有人'; }

export async function handleCommunityRoutes(ctx) {
  const { req, res, url, env, rid, db, actor, body, json, required, enforceRate, mediaStorage } = ctx;
  if (req.method === 'GET' && url.pathname === '/api/posts') {
    const { userId } = await actor(req); const mode = url.searchParams.get('mode');
    let where = "WHERE (p.visibility='所有人' OR p.user_id=?) AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id=? AND b.blocked_user_id=p.user_id)"; let params = [userId, userId];
    if (mode === '关注') { where += ' AND p.user_id IN (?,?)'; params.push(userId, 'forest-letter'); }
    if (mode === '附近') where += " AND p.place_name<>''";
    const limit = Math.min(50, Math.max(1, Number(url.searchParams.get('limit') || 20))); const offset = Math.max(0, Number(url.searchParams.get('offset') || 0));
    const rows = await postRows(db, where, params, userId); json(res, 200, rows.slice(offset, offset + limit).map(protectCommunityLocation), env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/posts') {
    const input = await body(req); const { user, userId } = await actor(req, input); await enforceRate(`post:${userId}`, 20, 60 * 1000);
    const title = required(input.title, 'TITLE'); const postBody = required(input.body, 'BODY');
    if (title.length > 120 || postBody.length > 10000) throw new Error('INVALID_TEXT_LENGTH');
    const id = `post-${Date.now()}-${Math.floor(Math.random() * 10000)}`; const now = new Date().toISOString(); let imageUrl = ''; let createdMedia = null;
    if (input.mediaId) { if (!user) throw new Error('AUTH_REQUIRED'); const media = await db.prepare('SELECT * FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(input.mediaId, userId); if (!media) throw new Error('MEDIA_NOT_FOUND'); await db.prepare('UPDATE media SET expires_at=? WHERE id=?').run(Date.now() + 365 * 24 * 60 * 60 * 1000, media.id); imageUrl = `/media/${media.file_name}`; }
    else if (input.imageBase64) { const decoded = decodeDataUrl(input.imageBase64); createdMedia = await saveMedia({ db, storage: mediaStorage, userId, buffer: decoded.buffer, mime: decoded.mime, ttlMs: 365 * 24 * 60 * 60 * 1000 }); imageUrl = createdMedia.url; }
    const authorName = user?.displayName || input.authorName || '林中客';
    try { await db.prepare(`INSERT INTO posts(id,user_id,author_name,type,title,body,species_id,behavior,place_name,visibility,image_url,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(id, userId, authorName, input.type === 'journal' ? 'journal' : 'photo', title, postBody, String(input.speciesId || '').slice(0, 120), String(input.behavior || '').slice(0, 120), String(input.placeName || '').slice(0, 200), normalizeVisibility(input.visibility), imageUrl, now, now); }
    catch (error) {
      if (createdMedia) {
        const removed = await removeStoredMedia(mediaStorage, { file_name: createdMedia.url.slice('/media/'.length) });
        if (removed) await db.prepare('DELETE FROM media WHERE id=?').run(createdMedia.id);
        else await db.prepare('UPDATE media SET expires_at=? WHERE id=?').run(Date.now(), createdMedia.id);
      }
      throw error;
    }
    json(res, 201, protectCommunityLocation((await postRows(db, 'WHERE p.id=?', [id], userId))[0]), env, rid); return true;
  }
  const postMatch = url.pathname.match(/^\/api\/posts\/([^/]+)$/);
  if (req.method === 'GET' && postMatch) { const { userId } = await actor(req); const rows = await postRows(db, 'WHERE p.id=? AND NOT EXISTS (SELECT 1 FROM user_blocks b WHERE b.blocker_id=? AND b.blocked_user_id=p.user_id)', [postMatch[1], userId], userId); if (rows.length && (rows[0].visibility === '所有人' || rows[0].userId === userId)) json(res, 200, protectCommunityLocation(rows[0]), env, rid); else json(res, 404, { error: 'POST_NOT_FOUND' }, env, rid); return true; }
  if (req.method === 'DELETE' && postMatch) { const { userId } = await actor(req, {}, true); const post = await db.prepare('SELECT id,user_id,image_url FROM posts WHERE id=?').get(postMatch[1]); if (!post) throw new Error('POST_NOT_FOUND'); if (post.user_id !== userId) throw new Error('FORBIDDEN'); await db.transaction(async tx => { await tx.prepare('DELETE FROM posts WHERE id=?').run(post.id); if (post.image_url?.startsWith('/media/')) await tx.prepare('UPDATE media SET expires_at=? WHERE file_name=?').run(Date.now(), post.image_url.slice('/media/'.length)); }); json(res, 200, { ok: true, id: post.id }, env, rid); return true; }
  const reactionMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/(like|favorite)$/);
  if (req.method === 'POST' && reactionMatch) { const input = await body(req, 64 * 1024); const { userId } = await actor(req, input); const post = await db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(reactionMatch[1]); const blocked = post ? await db.prepare('SELECT 1 AS blocked FROM user_blocks WHERE blocker_id=? AND blocked_user_id=?').get(userId, post.user_id) : null; if (!post || (post.visibility !== '所有人' && post.user_id !== userId) || blocked) throw new Error('POST_NOT_FOUND'); await setReaction(db, reactionMatch[1], userId, reactionMatch[2] === 'like' ? 'liked' : 'favorite', input.value !== false); json(res, 200, protectCommunityLocation((await postRows(db, 'WHERE p.id=?', [reactionMatch[1]], userId))[0]), env, rid); return true; }
  const commentsMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/comments$/);
  if (commentsMatch && req.method === 'GET') { const { userId } = await actor(req); const post = await db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(commentsMatch[1]); if (!post || (post.visibility !== '所有人' && post.user_id !== userId)) throw new Error('POST_NOT_FOUND'); const rows = await db.prepare('SELECT id,post_id,user_id,author_name,body,created_at FROM comments WHERE post_id=? ORDER BY created_at ASC').all(commentsMatch[1]); json(res, 200, rows.map(row => ({ id: row.id, postId: row.post_id, userId: row.user_id, authorName: row.author_name, body: row.body, createdAt: row.created_at })), env, rid); return true; }
  if (commentsMatch && req.method === 'POST') { const input = await body(req, 128 * 1024); const { user, userId } = await actor(req, input); await enforceRate(`comment:${userId}`, 60, 60 * 1000); const id = `comment-${Date.now()}-${Math.floor(Math.random() * 10000)}`; const now = new Date().toISOString(); const post = await db.prepare('SELECT user_id,visibility FROM posts WHERE id=?').get(commentsMatch[1]); const blocked = post ? await db.prepare('SELECT 1 AS blocked FROM user_blocks WHERE blocker_id=? AND blocked_user_id=?').get(userId, post.user_id) : null; if (!post || (post.visibility !== '所有人' && post.user_id !== userId) || blocked) throw new Error('POST_NOT_FOUND'); const commentBody = required(input.body, 'BODY'); if (commentBody.length > 2000) throw new Error('INVALID_TEXT_LENGTH'); const authorName = user?.displayName || input.authorName || '林中客'; await db.prepare('INSERT INTO comments(id,post_id,user_id,author_name,body,created_at) VALUES(?,?,?,?,?,?)').run(id, commentsMatch[1], userId, authorName, commentBody, now); json(res, 201, { id, postId: commentsMatch[1], userId, authorName, body: commentBody, createdAt: now }, env, rid); return true; }
  const reportMatch = url.pathname.match(/^\/api\/posts\/([^/]+)\/report$/);
  if (req.method === 'POST' && reportMatch) { const input = await body(req, 64 * 1024); const { userId } = await actor(req, {}, true); if (!await db.prepare('SELECT id FROM posts WHERE id=?').get(reportMatch[1])) throw new Error('POST_NOT_FOUND'); const id = `report-${Date.now()}-${randomBytes(5).toString('hex')}`; const reason = required(input.reason || '未说明', 'REASON'); if (reason.length > 1000) throw new Error('INVALID_TEXT_LENGTH'); await db.prepare('INSERT INTO content_reports(id,reporter_id,post_id,reason,status,created_at) VALUES(?,?,?,?,?,?)').run(id, userId, reportMatch[1], reason, 'open', Date.now()); json(res, 201, { ok: true, id, status: 'open' }, env, rid); return true; }
  const blockMatch = url.pathname.match(/^\/api\/users\/([^/]+)\/block$/);
  if (req.method === 'POST' && blockMatch) { const { userId } = await actor(req, {}, true); if (blockMatch[1] === userId) throw new Error('INVALID_BLOCK_TARGET'); await db.prepare('INSERT INTO user_blocks(blocker_id,blocked_user_id,created_at) VALUES(?,?,?) ON CONFLICT(blocker_id,blocked_user_id) DO NOTHING').run(userId, blockMatch[1], Date.now()); json(res, 200, { ok: true, blockedUserId: blockMatch[1] }, env, rid); return true; }
  return false;
}
