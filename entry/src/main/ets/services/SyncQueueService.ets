import { SyncJob } from '../models/SyncModels';

export class SyncQueueService {
  static createJob(action: string, entityId: string, payload: string): SyncJob {
    const now = new Date().getTime().toString();
    return {
      id: 'sync-' + now + '-' + entityId,
      action: action,
      entityId: entityId,
      payload: payload,
      status: 'pending',
      retryCount: 0,
      createdAt: now,
      updatedAt: now
    };
  }

  static pendingCount(jobs: SyncJob[]): number {
    return jobs.filter((item: SyncJob) => item.status === 'pending').length;
  }

  static failedCount(jobs: SyncJob[]): number {
    return jobs.filter((item: SyncJob) => item.status === 'failed').length;
  }

  static markPendingAsSynced(jobs: SyncJob[]): SyncJob[] {
    const now = new Date().getTime().toString();
    return jobs.map((item: SyncJob) => {
      if (item.status !== 'pending') {
        return item;
      }
      return {
        id: item.id,
        action: item.action,
        entityId: item.entityId,
        payload: item.payload,
        status: 'synced',
        retryCount: item.retryCount,
        createdAt: item.createdAt,
        updatedAt: now
      };
    });
  }

  static compactSynced(jobs: SyncJob[]): SyncJob[] {
    return jobs.filter((item: SyncJob) => item.status !== 'synced');
  }
}
