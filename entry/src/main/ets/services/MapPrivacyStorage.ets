import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'map_settings';
const AGREED_KEY: string = 'tencent_map_privacy_agreed';

export class MapPrivacyStorage {
  static async load(context: common.Context): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      return await store.get(AGREED_KEY, false) as boolean;
    } catch (error) {
      return false;
    }
  }

  static async save(context: common.Context, agreed: boolean): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(AGREED_KEY, agreed);
      await store.flush();
      return true;
    } catch (error) {
      return false;
    }
  }
}
