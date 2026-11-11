import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { AuthSession } from '../models/BetaModels';
import { AuthSessionPolicy } from './AuthSessionPolicy';

const STORE_NAME = 'birdfolio_auth';
const SESSION_KEY = 'session';
const SESSION_ALIAS = 'birdfolio.auth.session.v1';

export interface SecureSessionStore {
  load(): Promise<string>;
  save(value: string): Promise<boolean>;
  clear(): Promise<boolean>;
}

export class AssetSessionStore implements SecureSessionStore {
  private bytes(value: string): Uint8Array {
    return util.TextEncoder.create().encodeInto(value);
  }

  async load(): Promise<string> {
    try {
      const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, this.bytes(SESSION_ALIAS));
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
      query.set(asset.Tag.RETURN_LIMIT, 1);
      const results = await asset.query(query);
      if (results.length === 0) return '';
      const secret = results[0].get(asset.Tag.SECRET);
      if (!(secret instanceof Uint8Array)) return '';
      return util.TextDecoder.create('utf-8').decodeToString(secret);
    } catch (_error) {
      return '';
    }
  }

  async save(value: string): Promise<boolean> {
    try {
      if (!await this.clear()) return false;
      const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      attributes.set(asset.Tag.ALIAS, this.bytes(SESSION_ALIAS));
      attributes.set(asset.Tag.SECRET, this.bytes(value));
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
      attributes.set(asset.Tag.IS_PERSISTENT, false);
      await asset.add(attributes);
      return true;
    } catch (_error) {
      return false;
    }
  }

  async clear(): Promise<boolean> {
    try {
      const query: asset.AssetMap = new Map<asset.Tag, asset.Value>();
      query.set(asset.Tag.ALIAS, this.bytes(SESSION_ALIAS));
      await asset.remove(query);
      return true;
    } catch (_error) {
      return false;
    }
  }
}

/**
 * Local-only session storage. A missing or malformed session is treated as
 * guest mode; observation data is never removed when a session expires.
 */
export class AuthStorage {
  static async load(context: common.UIAbilityContext, secureStore: SecureSessionStore = new AssetSessionStore()): Promise<AuthSession | null> {
    const secure = AuthSessionPolicy.parse(await secureStore.load());
    if (secure) {
      // Retry legacy cleanup on every successful secure load. This covers an
      // interrupted upgrade between writing Asset Store and flushing Preferences.
      await AuthStorage.removeLegacy(context);
      return secure;
    }

    // One-time migration from the old plaintext preference. Failure is fail-closed:
    // delete the legacy value and return guest mode instead of retaining plaintext.
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(SESSION_KEY, '');
      if (typeof raw !== 'string' || raw.length === 0) return null;
      const legacy = AuthSessionPolicy.parse(raw);
      if (legacy && await secureStore.save(JSON.stringify(legacy))) {
        await store.delete(SESSION_KEY);
        await store.flush();
        return legacy;
      }
      await store.delete(SESSION_KEY);
      await store.flush();
      return null;
    } catch (_error) {
      return null;
    }
  }

  static async save(context: common.UIAbilityContext, session: AuthSession, secureStore: SecureSessionStore = new AssetSessionStore()): Promise<boolean> {
    const normalized = AuthSessionPolicy.normalize(session);
    if (!normalized) return false;
    const saved = await secureStore.save(JSON.stringify(normalized));
    if (!saved) return false;
    if (await AuthStorage.removeLegacy(context)) return true;
    await secureStore.clear();
    return false;
  }

  static async clear(context: common.UIAbilityContext, secureStore: SecureSessionStore = new AssetSessionStore()): Promise<boolean> {
    const secureCleared = await secureStore.clear();
    const legacyCleared = await AuthStorage.removeLegacy(context);
    return secureCleared && legacyCleared;
  }

  private static async removeLegacy(context: common.UIAbilityContext): Promise<boolean> {
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
    return AuthSessionPolicy.accessToken(session);
  }

  static isAccessTokenFresh(session: AuthSession | null, skewSeconds: number = 30): boolean {
    return AuthSessionPolicy.isAccessTokenFresh(session, skewSeconds);
  }

  static normalize(value: AuthSession): AuthSession | null {
    return AuthSessionPolicy.normalize(value);
  }

  static parse(raw: string): AuthSession | null {
    return AuthSessionPolicy.parse(raw);
  }
}
