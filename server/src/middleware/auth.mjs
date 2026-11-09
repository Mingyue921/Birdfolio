import { bearerToken, LEGACY_USER_ID } from '../auth.mjs';

export function createActor({ auth, env, requireAuthByDefault }) {
  return function actor(req, input = {}, requiredAuth = requireAuthByDefault) {
    const presented = bearerToken(req); const user = presented ? auth.authenticateToken(presented) : null;
    if (presented && !user) throw new Error('INVALID_TOKEN');
    if (requiredAuth && !user) throw new Error('AUTH_REQUIRED');
    const legacyAllowed = String(env.ALLOW_LEGACY_DEMO ??
      (String(env.REQUIRE_AUTH || '').toLowerCase() === 'true' ? 'false' : 'true')).toLowerCase() !== 'false';
    if (!user && !legacyAllowed) throw new Error('AUTH_REQUIRED');
    return { user, userId: user?.id || String(input.userId || LEGACY_USER_ID), authenticated: Boolean(user) };
  };
}
