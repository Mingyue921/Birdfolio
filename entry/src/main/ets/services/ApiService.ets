import { http } from '@kit.NetworkKit';
import { CommunityPost, CreatePostInput, HealthResult, Observation, PostComment, SpeciesCatalogResult } from '../models/BirdModels';
import {
  AccountExportResult,
  ApiErrorBody,
  AuthCodeRequestResult,
  AuthRefreshInput,
  AuthSession,
  AuthUser,
  AuthVerifyInput,
  IdentificationConfirmation,
  IdentificationFeedbackInput,
  IdentificationMetadata,
  IdentificationResultV2,
  MediaAsset,
  MediaUploadInput,
  SyncPullResult,
  SyncPushInput,
  SyncPushResult,
  SyncResolveInput
} from '../models/BetaModels';

interface ReactionInput {
  value: boolean;
}

interface CommentInput {
  authorName: string;
  body: string;
}

interface DeletedObservation {
  id: string;
  updatedAt: string;
  deleted: boolean;
}

interface RawAuthSession {
  accessToken?: string;
  access_token?: string;
  token?: string;
  refreshToken?: string;
  refresh_token?: string;
  expiresAt?: number;
  expires_at?: number;
  expiresIn?: number;
  expires_in?: number;
  userId?: string;
  user_id?: string;
  email?: string;
  displayName?: string;
  display_name?: string;
  user?: AuthUser;
}

interface RawAuthCodeResponse {
  ok?: boolean;
  accepted?: boolean;
  message?: string;
  expiresIn?: number;
  expires_in?: number;
  retryAfterSeconds?: number;
  retry_after?: number;
  debugCode?: string;
}

interface RawMediaAsset {
  mediaId?: string;
  id?: string;
  url?: string;
  path?: string;
  mimeType?: string;
  mime_type?: string;
  sizeBytes?: number;
  size_bytes?: number;
  byteSize?: number;
  expiresAt?: string;
  expires_at?: string;
}

interface RequestHeaders {
  'Content-Type': string;
  'Authorization'?: string;
}

interface EmptyPayload {}

interface LoginCodeInput {
  email: string;
}

interface MediaUploadRequest {
  dataUrl: string;
  imageBase64: string;
  fileName: string;
  mimeType: string;
}

interface IdentifyMediaRequest {
  mediaId: string;
  placeName: string;
  observedAt: string;
  habitat: string;
  latitude?: number;
  longitude?: number;
}

interface ConfirmIdentificationRequest {
  requestId: string;
  speciesId: string;
  observation?: Observation;
}

interface IdentificationFeedbackRequest {
  requestId: string;
  selectedSpeciesId: string;
  speciesId: string;
  accepted: boolean;
  rating: string;
  note: string;
  reason: string;
}

export class ApiServiceError extends Error {
  readonly statusCode: number;
  readonly errorCode: string;
  readonly requestId: string;

  constructor(statusCode: number, errorCode: string, requestId: string = '') {
    super(errorCode);
    this.name = 'ApiServiceError';
    this.statusCode = statusCode;
    this.errorCode = errorCode;
    this.requestId = requestId;
  }
}

/**
 * Thin HTTP client shared by the optional cloud account, AI and sync flows.
 * Existing community and observation methods intentionally keep their old
 * signatures so the offline-first app can continue to work unchanged.
 */
export class ApiService {
  private baseUrl: string;
  private accessToken: string;

  constructor(baseUrl: string, accessToken: string = '') {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.accessToken = accessToken.trim();
  }

  setAccessToken(token: string): void { this.accessToken = token.trim(); }
  clearAccessToken(): void { this.accessToken = ''; }
  getBaseUrl(): string { return this.baseUrl; }

  private async request<T>(path: string, method: http.RequestMethod = http.RequestMethod.GET, payload?: Object, readTimeout: number = 18000): Promise<T> {
    const client = http.createHttp();
    try {
      const headers: RequestHeaders = this.accessToken.length > 0
        ? { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + this.accessToken }
        : { 'Content-Type': 'application/json' };
      const options: http.HttpRequestOptions = {
        method: method,
        connectTimeout: 5000,
        readTimeout: readTimeout,
        header: headers,
        extraData: payload ? JSON.stringify(payload) : ''
      };
      const response = await client.request(this.baseUrl + path, options);
      const text = typeof response.result === 'string' ? response.result : JSON.stringify(response.result);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        let errorCode = 'HTTP_' + response.responseCode.toString();
        let requestId = '';
        try {
          const parsed = JSON.parse(text || '{}') as ApiErrorBody;
          if (parsed.error && parsed.error.length > 0) errorCode = parsed.error;
          else if (parsed.code && parsed.code.length > 0) errorCode = parsed.code;
          if (parsed.requestId) requestId = parsed.requestId;
        } catch (_parseError) {
          // Keep the HTTP status when a proxy returns a non-JSON error body.
        }
        throw new ApiServiceError(response.responseCode, errorCode, requestId);
      }
      if (!text || text.length === 0) {
        const emptyResponse: EmptyPayload = {};
        return emptyResponse as T;
      }
      return JSON.parse(text) as T;
    } catch (error) {
      if (error instanceof ApiServiceError) throw error;
      const message = error instanceof Error && error.message.length > 0 ? error.message : 'NETWORK_ERROR';
      throw new ApiServiceError(0, message);
    } finally {
      client.destroy();
    }
  }

  health(): Promise<HealthResult> { return this.request<HealthResult>('/api/health'); }

  species(query: string = '', limit: number = 20): Promise<SpeciesCatalogResult> {
    return this.request<SpeciesCatalogResult>('/api/species?q=' + encodeURIComponent(query) + '&limit=' + limit.toString(), http.RequestMethod.GET, undefined, 40000);
  }

  posts(mode: string): Promise<CommunityPost[]> {
    return this.request<CommunityPost[]>('/api/posts?mode=' + encodeURIComponent(mode));
  }

  createPost(input: CreatePostInput): Promise<CommunityPost> { return this.request<CommunityPost>('/api/posts', http.RequestMethod.POST, input); }
  post(id: string): Promise<CommunityPost> { return this.request<CommunityPost>('/api/posts/' + encodeURIComponent(id)); }
  comments(id: string): Promise<PostComment[]> { return this.request<PostComment[]>('/api/posts/' + encodeURIComponent(id) + '/comments'); }

  addComment(id: string, body: string): Promise<PostComment> {
    const input: CommentInput = { authorName: '林中客', body: body };
    return this.request<PostComment>('/api/posts/' + encodeURIComponent(id) + '/comments', http.RequestMethod.POST, input);
  }

  react(id: string, kind: 'like' | 'favorite', value: boolean): Promise<CommunityPost> {
    const input: ReactionInput = { value: value };
    return this.request<CommunityPost>('/api/posts/' + encodeURIComponent(id) + '/' + kind, http.RequestMethod.POST, input);
  }

  syncObservation(observation: Observation): Promise<Object> {
    return this.request<Object>('/api/observations/' + encodeURIComponent(observation.id), http.RequestMethod.PUT, observation);
  }

  deleteObservation(id: string, updatedAt: string): Promise<Object> {
    const input: DeletedObservation = { id: id, updatedAt: updatedAt, deleted: true };
    return this.request<Object>('/api/observations/' + encodeURIComponent(id), http.RequestMethod.PUT, input);
  }

  // Authentication -------------------------------------------------------

  async requestLoginCode(email: string): Promise<AuthCodeRequestResult> {
    const input: LoginCodeInput = { email: email.trim() };
    const raw = await this.request<RawAuthCodeResponse>('/api/auth/request-code', http.RequestMethod.POST, input, 20000);
    return {
      accepted: raw.accepted === true || raw.ok === true,
      message: raw.message || '',
      expiresInSeconds: Number(raw.expiresIn || raw.expires_in || 0),
      retryAfterSeconds: Number(raw.retryAfterSeconds || raw.retry_after || 0),
      debugCode: raw.debugCode
    };
  }

  async verifyLoginCode(input: AuthVerifyInput): Promise<AuthSession> {
    const raw = await this.request<RawAuthSession>('/api/auth/verify-code', http.RequestMethod.POST, input, 20000);
    const session = ApiService.normalizeSession(raw);
    this.setAccessToken(session.accessToken);
    return session;
  }

  async refreshSession(refreshToken: string): Promise<AuthSession> {
    const input: AuthRefreshInput = { refreshToken: refreshToken };
    const raw = await this.request<RawAuthSession>('/api/auth/refresh', http.RequestMethod.POST, input, 20000);
    const session = ApiService.normalizeSession(raw);
    this.setAccessToken(session.accessToken);
    return session;
  }

  async logout(refreshToken: string = ''): Promise<Object> {
    const payload: AuthRefreshInput = { refreshToken: refreshToken };
    const result = await this.request<Object>('/api/auth/logout', http.RequestMethod.POST, payload, 10000);
    this.clearAccessToken();
    return result;
  }

  async me(): Promise<AuthUser> {
    const raw = await this.request<RawAuthSession>('/api/me');
    return raw.user ? raw.user : {
      id: raw.userId || raw.user_id || '',
      email: raw.email || '',
      displayName: raw.displayName || raw.display_name || ''
    };
  }

  exportAccount(): Promise<AccountExportResult> {
    const payload: EmptyPayload = {};
    return this.request<AccountExportResult>('/api/account/export', http.RequestMethod.POST, payload, 30000);
  }

  deleteAccount(): Promise<Object> {
    return this.request<Object>('/api/account', http.RequestMethod.DELETE, undefined, 30000);
  }

  // Controlled media and AI flow ----------------------------------------

  async uploadMedia(input: MediaUploadInput): Promise<MediaAsset> {
    const payload: MediaUploadRequest = {
      dataUrl: input.dataUrl,
      imageBase64: input.dataUrl,
      fileName: input.fileName || '',
      mimeType: input.mimeType || ''
    };
    const raw = await this.request<RawMediaAsset>('/api/media', http.RequestMethod.POST, payload, 40000);
    return ApiService.normalizeMedia(raw);
  }

  async identifyMedia(mediaId: string, metadata: IdentificationMetadata): Promise<IdentificationResultV2> {
    const payload: IdentifyMediaRequest = {
      mediaId: mediaId,
      placeName: metadata.placeName,
      observedAt: metadata.observedAt,
      habitat: metadata.habitat || '',
      latitude: metadata.latitude,
      longitude: metadata.longitude
    };
    return this.request<IdentificationResultV2>('/api/identify/image', http.RequestMethod.POST, payload, 50000);
  }

  confirmIdentification(requestId: string, speciesId: string, observation?: Observation): Promise<IdentificationConfirmation> {
    const payload: ConfirmIdentificationRequest = { requestId: requestId, speciesId: speciesId, observation: observation };
    return this.request<IdentificationConfirmation>('/api/identify/' + encodeURIComponent(requestId) + '/confirm', http.RequestMethod.POST, payload, 20000);
  }

  submitIdentificationFeedback(input: IdentificationFeedbackInput): Promise<Object> {
    const payload: IdentificationFeedbackRequest = {
      requestId: input.requestId,
      selectedSpeciesId: input.selectedSpeciesId,
      speciesId: input.selectedSpeciesId,
      accepted: input.accepted,
      rating: input.accepted ? 'accepted' : 'rejected',
      note: input.note || '',
      reason: input.note || ''
    };
    return this.request<Object>('/api/identify/' + encodeURIComponent(input.requestId) + '/feedback', http.RequestMethod.POST, payload, 15000);
  }

  // Incremental local-first synchronization -----------------------------

  pushSync(input: SyncPushInput): Promise<SyncPushResult> {
    return this.request<SyncPushResult>('/api/sync/push', http.RequestMethod.POST, input, 30000);
  }

  pullSync(cursor: string = ''): Promise<SyncPullResult> {
    const suffix = cursor.length > 0 ? '?cursor=' + encodeURIComponent(cursor) : '';
    return this.request<SyncPullResult>('/api/sync/pull' + suffix, http.RequestMethod.GET, undefined, 30000);
  }

  resolveSync(input: SyncResolveInput): Promise<SyncPushResult> {
    return this.request<SyncPushResult>('/api/sync/resolve', http.RequestMethod.POST, input, 30000);
  }

  static identificationStatusForError(errorCode: string): 'transport_error' | 'provider_error' | 'quota_exceeded' | 'unavailable' {
    const code = errorCode.toUpperCase();
    if (code === 'QUOTA_EXCEEDED' || code === 'HTTP_429') return 'quota_exceeded';
    if (code === 'PROVIDER_ERROR' || code === 'VISION_PROVIDER_ERROR' || code === 'HTTP_502' || code === 'HTTP_503') return 'provider_error';
    if (code === 'NETWORK_ERROR' || code === 'TIMEOUT' || code === 'HTTP_0') return 'transport_error';
    return 'unavailable';
  }

  mediaUrl(path: string): string {
    return path.startsWith('http://') || path.startsWith('https://') ? path : this.baseUrl + path;
  }

  private static normalizeSession(raw: RawAuthSession): AuthSession {
    const accessToken = raw.accessToken || raw.access_token || raw.token || '';
    const refreshToken = raw.refreshToken || raw.refresh_token || '';
    const userId = raw.userId || raw.user_id || raw.user?.id || '';
    const email = raw.email || raw.user?.email || '';
    let expiresAt = Number(raw.expiresAt || raw.expires_at || 0);
    if (expiresAt > 0 && expiresAt < 100000000000) expiresAt *= 1000;
    if (expiresAt <= 0) {
      const expiresIn = Number(raw.expiresIn || raw.expires_in || 0);
      if (Number.isFinite(expiresIn) && expiresIn > 0) expiresAt = new Date().getTime() + expiresIn * 1000;
    }
    if (accessToken.trim().length === 0 || userId.trim().length === 0) throw new ApiServiceError(200, 'INVALID_SESSION');
    return {
      accessToken: accessToken.trim(),
      refreshToken: refreshToken,
      expiresAt: Number.isFinite(expiresAt) ? expiresAt : 0,
      userId: userId.trim(),
      email: email.trim(),
      displayName: raw.displayName || raw.display_name || raw.user?.displayName || ''
    };
  }

  private static normalizeMedia(raw: RawMediaAsset): MediaAsset {
    const mediaId = raw.mediaId || raw.id || '';
    if (mediaId.length === 0) throw new ApiServiceError(200, 'INVALID_MEDIA_RESPONSE');
    return {
      mediaId: mediaId,
      url: raw.url || raw.path || '',
      mimeType: raw.mimeType || raw.mime_type || 'image/jpeg',
      sizeBytes: Number(raw.sizeBytes || raw.size_bytes || raw.byteSize || 0),
      expiresAt: String(raw.expiresAt || raw.expires_at || '')
    };
  }
}
