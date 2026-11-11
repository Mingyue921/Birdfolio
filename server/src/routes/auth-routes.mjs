import { bearerToken } from '../auth.mjs';

export async function handleAuthRoutes(ctx) {
  const { req, res, url, env, rid, auth, body, json, requireAuthByDefault, mailProvider } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/auth/request-code') {
    const input = await body(req, 64 * 1024);
    const debugAllowed = String(env.AUTH_DEBUG_CODES || '').toLowerCase() === 'true' || String(env.NODE_ENV || '').toLowerCase() === 'test';
    if (requireAuthByDefault && !String(env.MAIL_PROVIDER_URL || '').trim() && !debugAllowed) throw new Error('EMAIL_NOT_CONFIGURED');
    const result = await auth.requestCode(input.email, req.socket.remoteAddress || '');
    if (mailProvider.configured) await mailProvider.sendVerificationCode(result);
    const response = { ok: true, accepted: true, email: result.email, expiresIn: result.expiresIn, expiresInSeconds: result.expiresIn, retryAfterSeconds: 60, message: String(env.MAIL_PROVIDER_URL || '').trim() ? '验证码已发送' : '开发模式验证码已生成', delivery: String(env.MAIL_PROVIDER_URL || '').trim() ? 'email' : 'development' };
    if (result.debugCode) response.debugCode = result.debugCode;
    json(res, 200, response, env, rid); return true;
  }
  if (req.method === 'POST' && url.pathname === '/api/auth/verify-code') { const input = await body(req, 64 * 1024); json(res, 200, await auth.verifyCode(input.email, input.code), env, rid); return true; }
  if (req.method === 'POST' && url.pathname === '/api/auth/refresh') { const input = await body(req, 64 * 1024); json(res, 200, await auth.refresh(input.refreshToken), env, rid); return true; }
  if (req.method === 'POST' && url.pathname === '/api/auth/logout') { const input = await body(req, 64 * 1024); await auth.revokeAccess(bearerToken(req)); await auth.revokeRefresh(input.refreshToken); json(res, 200, { ok: true }, env, rid); return true; }
  return false;
}
