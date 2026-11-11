import { IdentificationCandidate, Observation } from './BirdModels';

/** Authentication state used by the optional cloud account flow. */
export type AuthMode = 'guest' | 'authenticated';

export interface AuthUser {
  id: string;
  email: string;
  displayName: string;
  avatarUri?: string;
  createdAt?: string;
}

export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  userId: string;
  email: string;
  displayName?: string;
}

export interface AuthCodeRequestResult {
  accepted: boolean;
  message: string;
  expiresInSeconds: number;
  retryAfterSeconds: number;
  debugCode?: string;
}

export interface AuthVerifyInput {
  email: string;
  code: string;
}

export interface AuthRefreshInput {
  refreshToken: string;
}

export interface ApiErrorBody {
  error?: string;
  message?: string;
  code?: string;
  requestId?: string;
}

export interface MediaUploadInput {
  dataUrl: string;
  fileName?: string;
  mimeType?: string;
  width?: number;
  height?: number;
}

export interface MediaAsset {
  mediaId: string;
  url: string;
  mimeType: string;
  sizeBytes: number;
  expiresAt: string;
}

export type IdentificationStatus =
  | 'transport_error'
  | 'provider_error'
  | 'quota_exceeded'
  | 'unavailable'
  | 'provider_success'
  | 'user_confirmed';

export interface AiServiceState {
  status: IdentificationStatus;
  available: boolean;
  message: string;
  requestId?: string;
  modelVersion?: string;
}

export interface IdentificationMetadata {
  placeName: string;
  observedAt: string;
  habitat?: string;
  latitude?: number;
  longitude?: number;
}

/** Extended result for the Beta flow; the old IdentificationResult remains supported. */
export interface IdentificationResultV2 {
  requestId: string;
  mode: 'provider' | 'demo' | 'unavailable';
  status: IdentificationStatus;
  candidates: IdentificationCandidate[];
  warning: string;
  modelVersion: string;
  elapsedMs: number;
  mediaId?: string;
}

export interface IdentificationConfirmInput {
  speciesId: string;
  requestId: string;
  observation?: Observation;
}

export interface IdentificationConfirmation {
  confirmed: boolean;
  requestId: string;
  speciesId: string;
  observationId?: string;
  status: IdentificationStatus;
  message: string;
}

export interface IdentificationFeedbackInput {
  requestId: string;
  selectedSpeciesId: string;
  accepted: boolean;
  note?: string;
}

export type SyncEntity = 'observation' | 'post' | 'journal' | 'profile';
export type SyncOperation = 'upsert' | 'delete';

export interface SyncMutation {
  mutationId: string;
  entity: SyncEntity;
  entityId: string;
  operation: SyncOperation;
  updatedAt: string;
  payload: string;
}

export interface SyncPushInput {
  mutations: SyncMutation[];
  idempotencyKey: string;
}

export interface SyncMutationResult {
  mutationId: string;
  entityId: string;
  result: 'applied' | 'unchanged' | 'conflict' | 'rejected';
  serverUpdatedAt: string;
  message?: string;
}

export interface SyncPushResult {
  results: SyncMutationResult[];
  nextCursor: string;
}

export interface SyncPullResult {
  cursor: string;
  /** Cursor returned by newer servers; older servers only return `cursor`. */
  nextCursor?: string;
  hasMore: boolean;
  mutations: SyncMutation[];
}

export interface SyncResolveInput {
  entity: SyncEntity;
  entityId: string;
  resolution: 'local' | 'remote';
  mutationId?: string;
}

export interface AccountExportResult {
  format?: string;
  generatedAt?: string;
  exportedAt?: string;
  userId?: string;
  payload?: string;
  observations?: Observation[];
  posts?: Object[];
  comments?: Object[];
}

export type PrivacyPurpose = 'identification' | 'cutout';

export interface ConsentRecord {
  purpose: PrivacyPurpose;
  policyVersion: string;
  agreedAt: number;
  revokedAt: number;
}

export interface PrivacySettings {
  /** Compatibility projection for existing identification UI. */
  aiPhotoUploadAgreed: boolean;
  diagnosticsEnabled: boolean;
  consents: ConsentRecord[];
}
