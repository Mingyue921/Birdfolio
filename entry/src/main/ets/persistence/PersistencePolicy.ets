import { LocalEntityMeta } from '../models/BirdModels';

export class PersistencePolicy {
  static readonly DATABASE_VERSION: number = 1;
  static readonly ORPHAN_GRACE_MS: number = 7 * 24 * 60 * 60 * 1000;

  static localMeta(value?: LocalEntityMeta, now: number = Date.now()): LocalEntityMeta {
    if (!value) return { version: 1, updatedAt: now, syncStatus: 'local' };
    const statuses: string[] = ['local', 'pending', 'synced', 'conflict'];
    return {
      version: Number.isFinite(value.version) && value.version > 0 ? Math.floor(value.version) : 1,
      updatedAt: Number.isFinite(value.updatedAt) && value.updatedAt > 0 ? value.updatedAt : now,
      deletedAt: value.deletedAt && value.deletedAt > 0 ? value.deletedAt : undefined,
      syncStatus: statuses.indexOf(value.syncStatus) >= 0 ? value.syncStatus : 'local'
    };
  }

  static uniqueAssetIds(ids: string[]): string[] {
    const result: string[] = [];
    ids.forEach((id: string) => { if (id.length > 0 && result.indexOf(id) < 0) result.push(id); });
    return result;
  }

  static orphanCutoff(now: number, graceMs: number = PersistencePolicy.ORPHAN_GRACE_MS): number {
    return now - Math.max(0, graceMs);
  }
}
