import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AuthSession } from '../models/BetaModels';

const STORE_NAME = 'birdfolio_auth';
const SESSION_KEY = 'session';

/**
 * Local-only session storage. A missing or malformed session is treated as
 * guest mode; observation data is never removed when a session expires.
 */
export class AuthStorage {
  static async load(context: common.UIAbilityContext): Promise<AuthSession | null> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(SESSION_KEY, '');
      if (typeof raw !== 'string' || raw.length === 0) return null;
      const parsed = JSON.parse(raw) as AuthSession;
      return AuthStorage.normalize(parsed);
    } catch (_error) {
      return null;
    }
  }

  static async save(context: common.UIAbilityContext, session: AuthSession): Promise<boolean> {
    const normalized = AuthStorage.normalize(session);
    if (!normalized) return false;
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(SESSION_KEY, JSON.stringify(normalized));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static async clear(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.delete(SESSION_KEY);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static accessToken(session: AuthSession | null): string {
    return session && session.accessToken ? session.accessToken : '';
  }

  static isAccessTokenFresh(session: AuthSession | null, skewSeconds: number = 30): boolean {
    if (!session || session.accessToken.length === 0) return false;
    if (!Number.isFinite(session.expiresAt) || session.expiresAt <= 0) return true;
    const now = new Date().getTime();
    return session.expiresAt > now + Math.max(0, skewSeconds) * 1000;
  }

  private static normalize(value: AuthSession): AuthSession | null {
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
}
