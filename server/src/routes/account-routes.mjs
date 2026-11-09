import { postRows } from '../database.mjs';
import { removeStoredMedia } from '../media.mjs';

export async function handleAccountRoutes(ctx) {
  const { req, res, url, env, rid, db, auth, actor, json, mediaStorage, observationRows } = ctx;
  if (req.method === 'GET' && url.pathname === '/api/me') {
    const { user } = await actor(req, {}, true); const safeUser = user ? { id: user.id, email: user.email, displayName: user.displayName, createdAt: user.createdAt, updatedAt: user.updatedAt } : null;
    json(res, 200, { ...(safeUser || {}), user: safeUser }, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/account/export') {
    const { userId } = await actor(req, {}, true); const generatedAt = new Date().toISOString();
    const bundle = { exportedAt: generatedAt, userId, observations: await observationRows(userId, true), posts: await postRows(db, 'WHERE p.user_id=?', [userId], userId), comments: await db.prepare('SELECT id,post_id,body,created_at FROM comments WHERE user_id=? ORDER BY created_at').all(userId) };
    json(res, 200, { format: 'birdfolio-json', generatedAt, payload: JSON.stringify(bundle), ...bundle }, env, rid); return true;
  }
  if (req.method !== 'DELETE' || url.pathname !== '/api/account') return false;
  const { userId } = await actor(req, {}, true); const mediaRows = await db.prepare('SELECT * FROM media WHERE user_id=?').all(userId); const postFiles = await db.prepare("SELECT image_url FROM posts WHERE user_id=? AND image_url<>''").all(userId);
  const deleteRows = async tx => {
    await tx.prepare('DELETE FROM comments WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM reactions WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM content_reports WHERE reporter_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(userId, userId); await tx.prepare('DELETE FROM posts WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_user_id=?').run(userId, userId); await tx.prepare('DELETE FROM identify_feedback WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM identify_requests WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM observations WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM media WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM sync_operations WHERE user_id=?').run(userId); await tx.prepare('DELETE FROM auth_codes WHERE email=(SELECT email FROM users WHERE id=?)').run(userId); await tx.prepare('UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at=0').run(Date.now(), userId); await tx.prepare('UPDATE users SET deleted_at=?,updated_at=? WHERE id=?').run(String(Date.now()), new Date().toISOString(), userId);
  };
  if (typeof db.transaction === 'function') await db.transaction(deleteRows);
  else { await db.exec('BEGIN'); try { await deleteRows(db); await db.exec('COMMIT'); } catch (error) { await db.exec('ROLLBACK'); throw error; } }
  const keys = new Set(mediaRows.map(row => row.file_name));
  postFiles.forEach(item => { if (item.image_url?.startsWith('/media/')) keys.add(item.image_url.slice('/media/'.length)); });
  await Promise.allSettled([...keys].map(file_name => removeStoredMedia(mediaStorage, { file_name })));
  json(res, 200, { ok: true }, env, rid); return true;
}
