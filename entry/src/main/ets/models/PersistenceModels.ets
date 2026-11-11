export type PersistedEntityType = 'observation' | 'journal' | 'syncJob' | 'postDraft';
export type MediaReferenceOwnerType = 'observation' | 'journal' | 'postDraft' | 'profile';

export interface MediaReference {
  assetId: string;
  ownerType: MediaReferenceOwnerType;
  ownerId: string;
  createdAt: number;
}

export interface MediaCleanupResult {
  scanned: number;
  removed: number;
  skipped: number;
}

export interface PersistenceMigrationState {
  key: string;
  completed: boolean;
  completedAt: number;
}

export interface PersistedPayload {
  id: string;
  payload: string;
  updatedAt: number;
}
