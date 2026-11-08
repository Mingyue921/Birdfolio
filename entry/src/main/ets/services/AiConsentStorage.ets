import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

const STORE_NAME = 'birdfolio_privacy';
const AI_UPLOAD_KEY = 'aiPhotoUploadAgreed';

export class AiConsentStorage {
  static async load(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const value = await store.get(AI_UPLOAD_KEY, false);
      return typeof value === 'boolean' ? value : false;
    } catch (_error) {
      return false;
    }
  }

  static async save(context: common.UIAbilityContext, agreed: boolean): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(AI_UPLOAD_KEY, agreed);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
