import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { fileIo as fs } from '@kit.CoreFileKit';
import { AuthStorage } from './AuthStorage';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';

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
    try { await BirdfolioDatabase.clear(context); } catch (_error) { success = false; }
    try { LocalDataCleanupService.removeDirectory(context.filesDir + '/media'); } catch (_error) { success = false; }
    for (const name of LOCAL_STORES) {
      try { await preferences.deletePreferences(context, name); } catch (_error) { success = false; }
    }
    return success;
  }

  static storeNames(): string[] { return LOCAL_STORES.slice(); }

  private static removeDirectory(path: string): void {
    let names: string[] = [];
    try { names = fs.listFileSync(path); } catch (_error) { return; }
    names.forEach((name: string) => {
      const child = path + '/' + name;
      if (fs.statSync(child).isDirectory()) LocalDataCleanupService.removeDirectory(child);
      else fs.unlinkSync(child);
    });
    fs.rmdirSync(path);
  }
}
