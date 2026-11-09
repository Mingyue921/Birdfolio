import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AuthStorage } from './AuthStorage';

const LOCAL_STORES: string[] = [
  'birdfolio_store',
  'birdfolio_journals',
  'birdfolio_community',
  'birdfolio_profile',
  'birdfolio_species',
  'birdfolio_sync',
  'birdfolio_backend',
  'birdfolio_privacy',
  'map_settings'
];

export class LocalDataCleanupService {
  static async clear(context: common.UIAbilityContext): Promise<boolean> {
    let success = await AuthStorage.clear(context);
    for (const name of LOCAL_STORES) {
      try { await preferences.deletePreferences(context, name); } catch (_error) { success = false; }
    }
    return success;
  }

  static storeNames(): string[] { return LOCAL_STORES.slice(); }
}
