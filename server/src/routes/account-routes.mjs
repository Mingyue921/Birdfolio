import { existsSync, unlinkSync } from 'node:fs';
import { basename, join } from 'node:path';
import { postRows } from '../database.mjs';
import { removeMediaFile } from '../media.mjs';

export async function handleAccountRoutes(ctx) {
  const { req, res, url, env, rid, db, auth, actor, json, dataDir, observationRows } = ctx;
  if (req.method === 'GET' && url.pathname === '/api/me') {
    const { user } = actor(req, {}, true); const safeUser = user ? { id: user.id, email: user.email, displayName: user.displayName, createdAt: user.createdAt, updatedAt: user.updatedAt } : null;
    json(res, 200, { ...(safeUser || {}), user: safeUser }, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/account/export') {
    const { userId } = actor(req, {}, true); const generatedAt = new Date().toISOString();
    const bundle = { exportedAt: generatedAt, userId, observations: observationRows(userId, true), posts: postRows(db, 'WHERE p.user_id=?', [userId], userId), comments: db.prepare('SELECT id,post_id,body,created_at FROM comments WHERE user_id=? ORDER BY created_at').all(userId) };
    json(res, 200, { format: 'birdfolio-json', generatedAt, payload: JSON.stringify(bundle), ...bundle }, env, rid); return true;
  }
  if (req.method !== 'DELETE' || url.pathname !== '/api/account') return false;
  const { userId } = actor(req, {}, true); const mediaRows = db.prepare('SELECT * FROM media WHERE user_id=?').all(userId); const postFiles = db.prepare("SELECT image_url FROM posts WHERE user_id=? AND image_url<>''").all(userId);
  db.exec('BEGIN');
  try {
    db.prepare('DELETE FROM comments WHERE user_id=?').run(userId); db.prepare('DELETE FROM reactions WHERE user_id=?').run(userId); db.prepare('DELETE FROM content_reports WHERE reporter_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(userId, userId); db.prepare('DELETE FROM posts WHERE user_id=?').run(userId); db.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_user_id=?').run(userId, userId); db.prepare('DELETE FROM identify_feedback WHERE user_id=?').run(userId); db.prepare('DELETE FROM identify_requests WHERE user_id=?').run(userId); db.prepare('DELETE FROM observations WHERE user_id=?').run(userId); db.prepare('DELETE FROM media WHERE user_id=?').run(userId); db.prepare('DELETE FROM sync_operations WHERE user_id=?').run(userId); db.prepare('DELETE FROM auth_codes WHERE email=(SELECT email FROM users WHERE id=?)').run(userId); db.prepare('UPDATE users SET deleted_at=?,updated_at=? WHERE id=?').run(Date.now(), new Date().toISOString(), userId); auth.revokeUser(userId); db.exec('COMMIT');
  } catch (error) { db.exec('ROLLBACK'); throw error; }
  mediaRows.forEach(removeMediaFile);
  postFiles.forEach(item => { if (!item.image_url?.startsWith('/media/')) return; const path = join(dataDir, 'uploads', basename(item.image_url)); if (existsSync(path)) { try { unlinkSync(path); } catch { /* best effort */ } } });
  json(res, 200, { ok: true }, env, rid); return true;
}
