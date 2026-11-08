import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { PrivacySettings } from '../models/BetaModels';

const STORE_NAME = 'birdfolio_privacy';
const AI_UPLOAD_KEY = 'aiPhotoUploadAgreed';
const DIAGNOSTICS_KEY = 'diagnosticsEnabled';

const DEFAULTS: PrivacySettings = {
  aiPhotoUploadAgreed: false,
  diagnosticsEnabled: false
};

/** Stores consent and diagnostics choices without touching observation data. */
export class PrivacyStorage {
  static async load(context: common.UIAbilityContext): Promise<PrivacySettings> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const ai = await store.get(AI_UPLOAD_KEY, DEFAULTS.aiPhotoUploadAgreed);
      const diagnostics = await store.get(DIAGNOSTICS_KEY, DEFAULTS.diagnosticsEnabled);
      return {
        aiPhotoUploadAgreed: typeof ai === 'boolean' ? ai : DEFAULTS.aiPhotoUploadAgreed,
        diagnosticsEnabled: typeof diagnostics === 'boolean' ? diagnostics : DEFAULTS.diagnosticsEnabled
      };
    } catch (_error) {
      return PrivacyStorage.defaults();
    }
  }

  static async save(context: common.UIAbilityContext, settings: PrivacySettings): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(AI_UPLOAD_KEY, settings.aiPhotoUploadAgreed === true);
      await store.put(DIAGNOSTICS_KEY, settings.diagnosticsEnabled === true);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static async setAiPhotoConsent(context: common.UIAbilityContext, agreed: boolean): Promise<boolean> {
    const current = await PrivacyStorage.load(context);
    current.aiPhotoUploadAgreed = agreed;
    return PrivacyStorage.save(context, current);
  }

  static async revokeAiPhotoConsent(context: common.UIAbilityContext): Promise<boolean> {
    return PrivacyStorage.setAiPhotoConsent(context, false);
  }

  private static defaults(): PrivacySettings {
    return {
      aiPhotoUploadAgreed: DEFAULTS.aiPhotoUploadAgreed,
      diagnosticsEnabled: DEFAULTS.diagnosticsEnabled
    };
  }
}
