import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME = 'birdfolio_backend';
const URL_KEY = 'baseUrl';
const DEFAULT_URL = 'http://127.0.0.1:8787';

export class BackendConfigStorage {
  /** The host-side endpoint exposed through an HDC reverse port. */
  static localUrl(): string { return DEFAULT_URL; }

  static normalize(value: string): string {
    const cleaned = value.trim().replace(/\/+$/, '');
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) return '';
    return cleaned;
  }

  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const value = await store.get(URL_KEY, DEFAULT_URL);
      return typeof value === 'string' && BackendConfigStorage.normalize(value).length > 0 ? BackendConfigStorage.normalize(value) : DEFAULT_URL;
    } catch (_error) {
      return DEFAULT_URL;
    }
  }

  static async save(context: common.UIAbilityContext, value: string): Promise<boolean> {
    const normalized = BackendConfigStorage.normalize(value);
    if (normalized.length === 0) return false;
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(URL_KEY, normalized);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
