import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { SyncJob } from '../models/SyncModels';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistedPayload } from '../models/PersistenceModels';

const STORE_NAME = 'birdfolio_store';
const SYNC_JOBS_KEY = 'syncJobs';

export class SyncQueueStorage {
  static async load(context: common.UIAbilityContext): Promise<SyncJob[]> {
    try {
      const rows = await BirdfolioDatabase.loadPayloads(context, 'sync_jobs');
      if (rows.length > 0) return SyncQueueStorage.parseRows(rows);
      if (await BirdfolioDatabase.isMigrated(context, SYNC_JOBS_KEY)) return [];
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(SYNC_JOBS_KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        const migrated = SyncQueueStorage.parse(raw);
        await SyncQueueStorage.saveDatabase(context, migrated);
        return migrated;
      }
      await SyncQueueStorage.saveDatabase(context, []);
    } catch (error) {
      return await SyncQueueStorage.loadLegacy(context);
    }
    return [];
  }

  static async save(context: common.UIAbilityContext, jobs: SyncJob[]): Promise<boolean> {
    try {
      await SyncQueueStorage.saveDatabase(context, jobs); return true;
    } catch (_databaseError) { return await SyncQueueStorage.saveLegacy(context, jobs); }
  }

  private static async saveDatabase(context: common.UIAbilityContext, jobs: SyncJob[]): Promise<void> {
    const rows: PersistedPayload[] = jobs.map((job: SyncJob): PersistedPayload => ({ id: job.id, payload: JSON.stringify(job), updatedAt: SyncQueueStorage.timestamp(job.updatedAt) }));
    await BirdfolioDatabase.replacePayloadsAndMarkMigrated(context, 'sync_jobs', rows, SYNC_JOBS_KEY);
  }

  private static parseRows(rows: PersistedPayload[]): SyncJob[] {
    const jobs: SyncJob[] = [];
    rows.forEach((row: PersistedPayload) => { try { const job = JSON.parse(row.payload) as SyncJob; if (job && job.id) jobs.push(job); } catch (_error) {} });
    return jobs;
  }

  private static parse(raw: string): SyncJob[] {
    try { const value = JSON.parse(raw) as SyncJob[]; return Array.isArray(value) ? value : []; } catch (_error) { return []; }
  }

  private static timestamp(value: string): number {
    const numeric = Number(value); if (Number.isFinite(numeric) && numeric > 0) return numeric;
    const parsed = Date.parse(value); return Number.isFinite(parsed) ? parsed : Date.now();
  }

  private static async loadLegacy(context: common.UIAbilityContext): Promise<SyncJob[]> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); const raw = await store.get(SYNC_JOBS_KEY, ''); return typeof raw === 'string' ? SyncQueueStorage.parse(raw) : []; } catch (_error) { return []; }
  }

  private static async saveLegacy(context: common.UIAbilityContext, jobs: SyncJob[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(SYNC_JOBS_KEY, JSON.stringify(jobs));
      await store.flush();
      return true;
    } catch (_error) { return false; }
  }
}
