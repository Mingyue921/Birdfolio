import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME = 'birdfolio_sync';
const CURSOR_KEY = 'observationCursor';

/** Stores only the server cursor; observations remain in the existing local store. */
export class SyncCursorStorage {
  static async load(context: common.UIAbilityContext): Promise<string> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const value = await store.get(CURSOR_KEY, '');
      return typeof value === 'string' ? value : '';
    } catch (_error) {
      return '';
    }
  }

  static async save(context: common.UIAbilityContext, cursor: string): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(CURSOR_KEY, cursor);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
