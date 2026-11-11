import { bearerToken } from '../auth.mjs';

export async function handleAuthRoutes(ctx) {
  const { req, res, url, env, rid, auth, body, json, requireAuthByDefault, mailProvider, enforceRate, writeObservation } = ctx;
  if (req.method === 'POST' && url.pathname === '/api/auth/demo-session') {
    if (String(env.DEPLOYMENT_PROFILE || '').toLowerCase() !== 'competition' || String(env.COMPETITION_DEMO_LOGIN || '').toLowerCase() !== 'true') throw new Error('DEMO_LOGIN_DISABLED');
    const ip = String(req.socket.remoteAddress || 'unknown').slice(0, 80); await enforceRate(`demo-session:${ip}`, Math.max(1, Number(env.DEMO_LOGIN_HOURLY_LIMIT || 5)), 60 * 60 * 1000);
    const session = await auth.createDemoSession({ lifetimeMs: Number(env.COMPETITION_ACCOUNT_TTL_MS || 24 * 60 * 60 * 1000) });
    const now = Date.now();
    await writeObservation(session.userId, { speciesId: 'egret', speciesName: '白鹭', observedAt: new Date(now - 86400000).toISOString(), placeName: '福州湿地（演示）', habitat: '湿地', fuzzyLocation: true, notes: '比赛演示种子数据', updatedAt: now - 86400000 }, `demo-observation-egret-${session.userId}`);
    await writeObservation(session.userId, { speciesId: 'sparrow', speciesName: '麻雀', observedAt: new Date(now - 3600000).toISOString(), placeName: '校园（演示）', habitat: '城市公园', fuzzyLocation: true, notes: '比赛演示种子数据', updatedAt: now - 3600000 }, `demo-observation-sparrow-${session.userId}`);
    json(res, 200, session, env, rid); return true;
  }
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
