import { AuthSession } from '../models/BetaModels';

/** Pure session validation shared by secure storage and desktop unit tests. */
export class AuthSessionPolicy {
  static accessToken(session: AuthSession | null): string {
    return session && session.accessToken ? session.accessToken : '';
  }

  static isAccessTokenFresh(session: AuthSession | null, skewSeconds: number = 30): boolean {
    if (!session || session.accessToken.length === 0) return false;
    if (!Number.isFinite(session.expiresAt) || session.expiresAt <= 0) return true;
    return session.expiresAt > Date.now() + Math.max(0, skewSeconds) * 1000;
  }

  static normalize(value: AuthSession): AuthSession | null {
    if (!value || typeof value.accessToken !== 'string' || value.accessToken.trim().length === 0) return null;
    if (typeof value.refreshToken !== 'string') return null;
    if (typeof value.userId !== 'string' || value.userId.trim().length === 0) return null;
    if (typeof value.email !== 'string') return null;
    const expiresAt = Number(value.expiresAt);
    return {
      accessToken: value.accessToken.trim(),
      refreshToken: value.refreshToken,
      expiresAt: Number.isFinite(expiresAt) ? expiresAt : 0,
      userId: value.userId.trim(),
      email: value.email.trim(),
      displayName: typeof value.displayName === 'string' ? value.displayName : ''
    };
  }

  static parse(raw: string): AuthSession | null {
    if (!raw) return null;
    try { return AuthSessionPolicy.normalize(JSON.parse(raw) as AuthSession); } catch (_error) { return null; }
  }
}
