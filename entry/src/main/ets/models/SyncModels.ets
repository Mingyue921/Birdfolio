export type SyncJobStatus = 'pending' | 'syncing' | 'synced' | 'failed' | 'conflict';

export interface SyncJob {
  id: string;
  action: string;
  entityId: string;
  payload: string;
  // Keep this as string for Preferences compatibility with older queue data.
  status: string;
  retryCount: number;
  createdAt: string;
  updatedAt: string;
  lastError?: string;
  nextRetryAt?: string;
}
