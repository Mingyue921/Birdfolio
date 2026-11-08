import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { UserProfile } from '../models/BirdModels';

const STORE_NAME = 'birdfolio_profile';
const PROFILE_KEY = 'profile';
const DEFAULT_PROFILE: UserProfile = {
  displayName: '林中客',
  bio: '在城市里寻找有翅膀的邻居',
  avatarUri: ''
};

export class ProfileStorage {
  static async load(context: common.UIAbilityContext): Promise<UserProfile> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(PROFILE_KEY, '');
      if (typeof raw !== 'string' || raw.length === 0) return ProfileStorage.defaults();
      const parsed = JSON.parse(raw) as UserProfile;
      return {
        displayName: typeof parsed.displayName === 'string' && parsed.displayName.trim().length > 0 ? parsed.displayName.trim() : DEFAULT_PROFILE.displayName,
        bio: typeof parsed.bio === 'string' ? parsed.bio : DEFAULT_PROFILE.bio,
        avatarUri: typeof parsed.avatarUri === 'string' ? parsed.avatarUri : ''
      };
    } catch (_error) {
      return ProfileStorage.defaults();
    }
  }

  static async save(context: common.UIAbilityContext, profile: UserProfile): Promise<boolean> {
    const normalized: UserProfile = {
      displayName: profile.displayName.trim(),
      bio: profile.bio.trim(),
      avatarUri: profile.avatarUri
    };
    if (normalized.displayName.length === 0) return false;
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(PROFILE_KEY, JSON.stringify(normalized));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }

  private static defaults(): UserProfile {
    return { displayName: DEFAULT_PROFILE.displayName, bio: DEFAULT_PROFILE.bio, avatarUri: DEFAULT_PROFILE.avatarUri };
  }
}
