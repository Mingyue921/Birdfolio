import { bearerToken } from '../auth.mjs';

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
  } catch { throw new Error('PROVIDER_UNAVAILABLE'); }
}

export async function handleAuthRoutes(ctx) {
  const { req, res, url, env, rid, auth, body, json, requireAuthByDefault } = ctx;
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
  return false;
}
