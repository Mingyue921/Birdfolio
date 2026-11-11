import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { ConsentRecord, PrivacyPurpose, PrivacySettings } from '../models/BetaModels';
import { PrivacyPolicy, PRIVACY_POLICY_VERSION } from './PrivacyPolicy';

const STORE_NAME = 'birdfolio_privacy';
const AI_UPLOAD_KEY = 'aiPhotoUploadAgreed';
const DIAGNOSTICS_KEY = 'diagnosticsEnabled';
const CONSENTS_KEY = 'consentRecords';
export { PRIVACY_POLICY_VERSION } from './PrivacyPolicy';

const DEFAULTS: PrivacySettings = {
  aiPhotoUploadAgreed: false,
  diagnosticsEnabled: false,
  consents: []
};

/** Stores consent and diagnostics choices without touching observation data. */
export class PrivacyStorage {
  static async load(context: common.UIAbilityContext): Promise<PrivacySettings> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const ai = await store.get(AI_UPLOAD_KEY, DEFAULTS.aiPhotoUploadAgreed);
      const diagnostics = await store.get(DIAGNOSTICS_KEY, DEFAULTS.diagnosticsEnabled);
      const consentRaw = await store.get(CONSENTS_KEY, '');
      let consents = PrivacyPolicy.parseConsents(typeof consentRaw === 'string' ? consentRaw : '');
      if (consents.length === 0 && ai === true) {
        // The legacy boolean represented the same identification purpose. Bind it
        // to the current policy so an upgraded user keeps the previously granted
        // permission; future policy-version changes still require fresh consent.
        consents = [PrivacyStorage.record('identification', true)];
        await store.put(CONSENTS_KEY, JSON.stringify(consents));
        await store.delete(AI_UPLOAD_KEY);
        await store.flush();
      }
      return PrivacyStorage.settings(consents, diagnostics === true);
    } catch (_error) {
      return PrivacyStorage.defaults();
    }
  }

  static async save(context: common.UIAbilityContext, settings: PrivacySettings): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(CONSENTS_KEY, JSON.stringify(settings.consents));
      await store.delete(AI_UPLOAD_KEY);
      await store.put(DIAGNOSTICS_KEY, settings.diagnosticsEnabled === true);
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  static async setAiPhotoConsent(context: common.UIAbilityContext, agreed: boolean): Promise<boolean> {
    return PrivacyStorage.setConsent(context, 'identification', agreed);
  }

  static async revokeAiPhotoConsent(context: common.UIAbilityContext): Promise<boolean> {
    return PrivacyStorage.setAiPhotoConsent(context, false);
  }

  static async setConsent(context: common.UIAbilityContext, purpose: PrivacyPurpose, agreed: boolean): Promise<boolean> {
    const current = await PrivacyStorage.load(context);
    const next = current.consents.filter((item: ConsentRecord) => item.purpose !== purpose);
    next.push(PrivacyStorage.record(purpose, agreed));
    return PrivacyStorage.save(context, PrivacyStorage.settings(next, current.diagnosticsEnabled));
  }

  static hasActiveConsent(settings: PrivacySettings, purpose: PrivacyPurpose): boolean {
    return PrivacyPolicy.hasActiveConsent(settings, purpose);
  }

  static latestRecord(settings: PrivacySettings, purpose: PrivacyPurpose): ConsentRecord | undefined {
    return PrivacyPolicy.latestRecord(settings, purpose);
  }

  static parseConsents(raw: string): ConsentRecord[] {
    return PrivacyPolicy.parseConsents(raw);
  }

  private static settings(consents: ConsentRecord[], diagnosticsEnabled: boolean): PrivacySettings {
    const settings: PrivacySettings = { aiPhotoUploadAgreed: false, diagnosticsEnabled, consents };
    settings.aiPhotoUploadAgreed = PrivacyStorage.hasActiveConsent(settings, 'identification');
    return settings;
  }

  private static record(purpose: PrivacyPurpose, agreed: boolean, version: string = PRIVACY_POLICY_VERSION): ConsentRecord {
    const now = Date.now();
    return { purpose, policyVersion: version, agreedAt: agreed ? now : 0, revokedAt: agreed ? 0 : now };
  }

  private static defaults(): PrivacySettings {
    return {
      aiPhotoUploadAgreed: DEFAULTS.aiPhotoUploadAgreed,
      diagnosticsEnabled: DEFAULTS.diagnosticsEnabled,
      consents: []
    };
  }
}
