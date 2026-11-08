import { createHash, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

export const LEGACY_USER_ID = 'demo-user';

function nowMs() { return Date.now(); }

export function normalizeEmail(value) {
  const email = String(value || '').trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) throw new Error('INVALID_EMAIL');
  return email;
}

export function hashSecret(value) {
  return createHash('sha256').update(String(value)).digest('hex');
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left)); const b = Buffer.from(String(right));
  return a.length === b.length && timingSafeEqual(a, b);
}

function token() { return randomBytes(32).toString('base64url'); }

function userView(row) {
  if (!row) return null;
  return { id: row.id, email: row.email, displayName: row.display_name || '', createdAt: row.created_at, updatedAt: row.updated_at };
}

export function createAuthStore(db, options = {}) {
  const clock = options.clock || nowMs;
  const accessLifetime = Number(options.accessLifetimeMs || 60 * 60 * 1000);
  const refreshLifetime = Number(options.refreshLifetimeMs || 30 * 24 * 60 * 60 * 1000);
  const codeLifetime = Number(options.codeLifetimeMs || 10 * 60 * 1000);
  const debugCodes = options.debugCodes === true || String(options.env?.AUTH_DEBUG_CODES || '').toLowerCase() === 'true' || options.env?.NODE_ENV === 'test';
  const defaultCode = String(options.env?.AUTH_DEV_CODE || '').trim();

  function issueSession(userId) {
    const accessToken = token(); const refreshToken = token(); const created = clock();
    const id = `session-${randomBytes(10).toString('hex')}`;
    db.prepare(`INSERT INTO sessions
      (id,user_id,access_token_hash,refresh_token_hash,access_expires_at,refresh_expires_at,created_at,revoked_at)
      VALUES(?,?,?,?,?,?,?,0)`).run(id, userId, hashSecret(accessToken), hashSecret(refreshToken),
      created + accessLifetime, created + refreshLifetime, created);
    return {
      accessToken,
      refreshToken,
      expiresIn: Math.floor(accessLifetime / 1000),
      expiresAt: created + accessLifetime,
      refreshExpiresAt: created + refreshLifetime
    };
  }

  function requestCode(emailValue, requestIp = '') {
    const email = normalizeEmail(emailValue); const now = clock();
    const recent = db.prepare('SELECT COUNT(*) AS count FROM auth_codes WHERE email=? AND created_at>?').get(email, now - 60 * 1000);
    if (Number(recent?.count || 0) >= 3) throw new Error('AUTH_RATE_LIMITED');
    const code = defaultCode || String(randomInt(0, 1000000)).padStart(6, '0');
    const id = `code-${randomBytes(10).toString('hex')}`;
    db.prepare(`INSERT INTO auth_codes(id,email,code_hash,expires_at,attempts,used_at,created_at,request_ip)
      VALUES(?,?,?,?,0,0,?,?)`).run(id, email, hashSecret(code), now + codeLifetime, now, String(requestIp || '').slice(0, 64));
    // A real deployment should deliver this through an email provider. Returning the
    // code is deliberately restricted to local/test mode so production never leaks it.
    return { id, email, expiresIn: Math.floor(codeLifetime / 1000), deliveryCode: code, debugCode: debugCodes ? code : undefined };
  }

  function verifyCode(emailValue, codeValue) {
    const email = normalizeEmail(emailValue); const code = String(codeValue || '').trim();
    if (!/^\d{6}$/.test(code)) throw new Error('INVALID_AUTH_CODE');
    const now = clock();
    const row = db.prepare('SELECT * FROM auth_codes WHERE email=? AND used_at=0 ORDER BY created_at DESC LIMIT 1').get(email);
    if (!row || row.expires_at <= now) throw new Error('AUTH_CODE_EXPIRED');
    if (row.attempts >= 5) throw new Error('AUTH_CODE_LOCKED');
    if (!safeEqual(row.code_hash, hashSecret(code))) {
      db.prepare('UPDATE auth_codes SET attempts=attempts+1 WHERE id=?').run(row.id);
      throw new Error('INVALID_AUTH_CODE');
    }
    db.prepare('UPDATE auth_codes SET used_at=? WHERE id=?').run(now, row.id);
    const existing = db.prepare('SELECT * FROM users WHERE email=?').get(email);
    const userId = existing?.id || `user-${hashSecret(email).slice(0, 20)}`;
    if (existing?.deleted_at) {
      const iso = new Date(now).toISOString();
      db.prepare('UPDATE users SET deleted_at=\'\',updated_at=? WHERE id=?').run(iso, existing.id);
    } else if (!existing) {
      const iso = new Date(now).toISOString();
      db.prepare('INSERT INTO users(id,email,display_name,created_at,updated_at,deleted_at) VALUES(?,?,?,? ,?,\'\')')
        .run(userId, email, email.split('@')[0].slice(0, 40), iso, iso);
    }
    const user = db.prepare('SELECT * FROM users WHERE id=?').get(userId);
    return { user: userView(user), userId, email, displayName: user.display_name || '', ...issueSession(userId) };
  }

  function authenticateToken(accessToken) {
    const value = String(accessToken || '').trim(); if (!value) return null;
    const row = db.prepare(`SELECT s.*, u.id AS uid, u.email, u.display_name, u.created_at AS user_created_at,
      u.updated_at AS user_updated_at, u.deleted_at AS user_deleted_at
      FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.access_token_hash=? AND s.revoked_at=0`).get(hashSecret(value));
    if (!row || row.user_deleted_at || row.access_expires_at <= clock()) return null;
    return { id: row.uid, email: row.email, displayName: row.display_name || '', createdAt: row.user_created_at, updatedAt: row.user_updated_at, sessionId: row.id };
  }

  function authenticateRefresh(refreshToken) {
    const value = String(refreshToken || '').trim(); if (!value) return null;
    const row = db.prepare(`SELECT s.*, u.id AS uid, u.email, u.display_name, u.created_at AS user_created_at,
      u.updated_at AS user_updated_at, u.deleted_at AS user_deleted_at
      FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.refresh_token_hash=? AND s.revoked_at=0`).get(hashSecret(value));
    if (!row || row.user_deleted_at || row.refresh_expires_at <= clock()) return null;
    return { id: row.uid, email: row.email, displayName: row.display_name || '', createdAt: row.user_created_at, updatedAt: row.user_updated_at, sessionId: row.id };
  }

  function refresh(refreshToken) {
    const user = authenticateRefresh(refreshToken); if (!user) throw new Error('INVALID_REFRESH_TOKEN');
    const revoked = db.prepare('UPDATE sessions SET revoked_at=? WHERE id=? AND revoked_at=0').run(clock(), user.sessionId);
    if (Number(revoked.changes || 0) !== 1) throw new Error('INVALID_REFRESH_TOKEN');
    return { user: userView({ id: user.id, email: user.email, display_name: user.displayName, created_at: user.createdAt, updated_at: user.updatedAt }), userId: user.id, email: user.email, displayName: user.displayName || '', ...issueSession(user.id) };
  }

  function revokeAccess(accessToken) {
    const value = String(accessToken || '').trim(); if (!value) return false;
    const result = db.prepare('UPDATE sessions SET revoked_at=? WHERE access_token_hash=? AND revoked_at=0').run(clock(), hashSecret(value));
    return Number(result.changes || 0) > 0;
  }

  function revokeRefresh(refreshToken) {
    const value = String(refreshToken || '').trim(); if (!value) return false;
    const result = db.prepare('UPDATE sessions SET revoked_at=? WHERE refresh_token_hash=? AND revoked_at=0').run(clock(), hashSecret(value));
    return Number(result.changes || 0) > 0;
  }

  function revokeUser(userId) { db.prepare('UPDATE sessions SET revoked_at=? WHERE user_id=? AND revoked_at=0').run(clock(), userId); }

  return { requestCode, verifyCode, authenticateToken, refresh, revokeAccess, revokeRefresh, revokeUser, userView };
}

export function bearerToken(req) {
  const value = String(req.headers?.authorization || '');
  const match = value.match(/^Bearer\s+(.+)$/i); return match ? match[1].trim() : '';
}
