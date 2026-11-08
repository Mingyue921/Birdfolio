import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SyncJob } from '../models/SyncModels';

const STORE_NAME = 'birdfolio_store';
const SYNC_JOBS_KEY = 'syncJobs';

export class SyncQueueStorage {
  static async load(context: common.UIAbilityContext): Promise<SyncJob[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(SYNC_JOBS_KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        return JSON.parse(raw) as SyncJob[];
      }
    } catch (error) {
      return [];
    }
    return [];
  }

  static async save(context: common.UIAbilityContext, jobs: SyncJob[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(SYNC_JOBS_KEY, JSON.stringify(jobs));
      await store.flush();
      return true;
    } catch (_error) {
      return false;
    }
  }
}
