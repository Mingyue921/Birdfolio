import { ConsentRecord, PrivacyPurpose, PrivacySettings } from '../models/BetaModels';

export const PRIVACY_POLICY_VERSION = '2026-11-beta-draft';

/** Pure consent rules. Every image-processing purpose is evaluated independently. */
export class PrivacyPolicy {
  static hasActiveConsent(settings: PrivacySettings, purpose: PrivacyPurpose): boolean {
    const record = settings.consents.find((item: ConsentRecord) => item.purpose === purpose);
    return record !== undefined && record.agreedAt > 0 && record.revokedAt === 0 &&
      record.policyVersion === PRIVACY_POLICY_VERSION;
  }

  static latestRecord(settings: PrivacySettings, purpose: PrivacyPurpose): ConsentRecord | undefined {
    return settings.consents.find((item: ConsentRecord) => item.purpose === purpose);
  }

  static parseConsents(raw: string): ConsentRecord[] {
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw) as ConsentRecord[];
      if (!Array.isArray(parsed)) return [];
      return parsed.filter((item: ConsentRecord) => item && (item.purpose === 'identification' || item.purpose === 'cutout'))
        .map((item: ConsentRecord): ConsentRecord => {
          return {
            purpose: item.purpose,
            policyVersion: String(item.policyVersion || ''),
            agreedAt: Number(item.agreedAt || 0),
            revokedAt: Number(item.revokedAt || 0)
          };
        });
    } catch (_error) { return []; }
  }
}
