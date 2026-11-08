import { basename, join } from 'node:path';
import { existsSync, unlinkSync } from 'node:fs';
import { bearerToken } from '../auth.mjs';
import { postRows } from '../database.mjs';
import { removeMediaFile } from '../media.mjs';

async function deliverAuthCode(env, result) {
  const endpoint = String(env.MAIL_PROVIDER_URL || '').trim();
  if (!endpoint) return;
  const headers = { 'content-type': 'application/json' };
  if (String(env.MAIL_PROVIDER_TOKEN || '').trim()) headers.authorization = 'Bearer ' + String(env.MAIL_PROVIDER_TOKEN).trim();
  try {
    const response = await fetch(endpoint, {
      method: 'POST', headers,
      body: JSON.stringify({ to: result.email, code: result.deliveryCode, expiresIn: result.expiresIn }),
      signal: AbortSignal.timeout(Number(env.MAIL_PROVIDER_TIMEOUT_MS || 5000))
    });
    if (!response.ok) throw new Error('HTTP_' + response.status.toString());
  } catch {
    throw new Error('PROVIDER_UNAVAILABLE');
  }
}

export async function handleAuthRoutes(ctx) {
  const { req, res, url, env, rid, db, auth, actor, body, json, dataDir, observationRows, requireAuthByDefault } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/auth/request-code') {
    const input = await body(req, 64 * 1024);
    const debugAllowed = String(env.AUTH_DEBUG_CODES || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'test';
    if (requireAuthByDefault && !String(env.MAIL_PROVIDER_URL || '').trim() && !debugAllowed) throw new Error('EMAIL_NOT_CONFIGURED');
    const result = auth.requestCode(input.email, req.socket.remoteAddress || '');
    await deliverAuthCode(env, result);
    const response = { ok: true, accepted: true, email: result.email, expiresIn: result.expiresIn, expiresInSeconds: result.expiresIn, retryAfterSeconds: 60, message: String(env.MAIL_PROVIDER_URL || '').trim() ? '验证码已发送' : '开发模式验证码已生成', delivery: String(env.MAIL_PROVIDER_URL || '').trim() ? 'email' : 'development' };
    if (result.debugCode) response.debugCode = result.debugCode;
    json(res, 200, response, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/auth/verify-code') { const input = await body(req, 64 * 1024); json(res, 200, auth.verifyCode(input.email, input.code), env, rid); return true; }
  if (req.method === 'POST' && url.pathname === '/api/auth/refresh') { const input = await body(req, 64 * 1024); json(res, 200, auth.refresh(input.refreshToken), env, rid); return true; }
  if (req.method === 'POST' && url.pathname === '/api/auth/logout') { const input = await body(req, 64 * 1024); auth.revokeAccess(bearerToken(req)); auth.revokeRefresh(input.refreshToken); json(res, 200, { ok: true }, env, rid); return true; }
  if (req.method === 'GET' && url.pathname === '/api/me') {
    const { user } = actor(req, {}, true);
    const safeUser = user ? { id: user.id, email: user.email, displayName: user.displayName, createdAt: user.createdAt, updatedAt: user.updatedAt } : null;
    json(res, 200, { ...(safeUser || {}), user: safeUser }, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/account/export') {
    const { userId } = actor(req, {}, true); const generatedAt = new Date().toISOString();
    const bundle = { exportedAt: generatedAt, userId, observations: observationRows(userId, true), posts: postRows(db, 'WHERE p.user_id=?', [userId], userId), comments: db.prepare('SELECT id,post_id,body,created_at FROM comments WHERE user_id=? ORDER BY created_at').all(userId) };
    json(res, 200, { format: 'birdfolio-json', generatedAt, payload: JSON.stringify(bundle), ...bundle }, env, rid); return true;
  }
  if (req.method === 'DELETE' && url.pathname === '/api/account') {
    const { userId } = actor(req, {}, true);
    const mediaRows = db.prepare('SELECT * FROM media WHERE user_id=?').all(userId);
    const postFiles = db.prepare("SELECT image_url FROM posts WHERE user_id=? AND image_url<>''").all(userId);
    db.exec('BEGIN');
    try {
      db.prepare('DELETE FROM comments WHERE user_id=?').run(userId); db.prepare('DELETE FROM reactions WHERE user_id=?').run(userId);
      db.prepare('DELETE FROM content_reports WHERE reporter_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(userId, userId);
      db.prepare('DELETE FROM posts WHERE user_id=?').run(userId); db.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_user_id=?').run(userId, userId);
      db.prepare('DELETE FROM identify_feedback WHERE user_id=?').run(userId); db.prepare('DELETE FROM identify_requests WHERE user_id=?').run(userId);
      db.prepare('DELETE FROM observations WHERE user_id=?').run(userId); db.prepare('DELETE FROM media WHERE user_id=?').run(userId);
      db.prepare('DELETE FROM sync_operations WHERE user_id=?').run(userId); db.prepare('DELETE FROM auth_codes WHERE email=(SELECT email FROM users WHERE id=?)').run(userId);
      db.prepare('UPDATE users SET deleted_at=?,updated_at=? WHERE id=?').run(Date.now(), new Date().toISOString(), userId);
      auth.revokeUser(userId); db.exec('COMMIT');
    } catch (error) { db.exec('ROLLBACK'); throw error; }
    mediaRows.forEach(removeMediaFile);
    postFiles.forEach(item => {
      if (!item.image_url?.startsWith('/media/')) return;
      const path = join(dataDir, 'uploads', basename(item.image_url));
      if (existsSync(path)) { try { unlinkSync(path); } catch { /* best effort */ } }
    });
    json(res, 200, { ok: true }, env, rid); return true;
  }
  return false;
}
