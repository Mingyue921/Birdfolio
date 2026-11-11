import type { IdentificationResult, Observation, Session } from '../types'

const API_ROOT = (import.meta.env.VITE_API_BASE_URL || '/api').replace(/\/$/, '')
const STORAGE_KEY = 'birdfolio.cloud.session.v1'

export class ApiError extends Error {
  constructor(public status: number, public code: string, public requestId = '') {
    super(code)
  }
}

export function readSession(): Session | null {
  try { return JSON.parse(sessionStorage.getItem(STORAGE_KEY) || 'null') as Session | null } catch { return null }
}

export function storeSession(session: Session | null) {
  if (session) sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session))
  else sessionStorage.removeItem(STORAGE_KEY)
}

async function parseResponse<T>(response: Response): Promise<T> {
  const payload = await response.json().catch(() => ({})) as Record<string, unknown>
  if (!response.ok) throw new ApiError(response.status, String(payload.error || `HTTP_${response.status}`), String(payload.requestId || response.headers.get('x-request-id') || ''))
  return payload as T
}

async function request<T>(path: string, init: RequestInit = {}, allowRefresh = true): Promise<T> {
  const session = readSession()
  const headers = new Headers(init.headers)
  if (!headers.has('content-type') && init.body) headers.set('content-type', 'application/json')
  if (session?.accessToken) headers.set('authorization', `Bearer ${session.accessToken}`)
  const response = await fetch(`${API_ROOT}${path}`, { ...init, headers })
  if (response.status === 401 && allowRefresh && session?.refreshToken) {
    try {
      const refreshed = await parseResponse<Session>(await fetch(`${API_ROOT}/auth/refresh`, {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ refreshToken: session.refreshToken }),
      }))
      storeSession(refreshed)
      return request<T>(path, init, false)
    } catch { storeSession(null) }
  }
  return parseResponse<T>(response)
}

export const api = {
  health: () => request<{ ok: boolean; aiMode: string; version: string }>('/health'),
  demoSession: () => request<Session>('/auth/demo-session', { method: 'POST', body: '{}' }, false),
  observations: () => request<Observation[]>('/observations'),
  uploadImage: (dataBase64: string) => request<{ mediaId: string }>('/media', { method: 'POST', body: JSON.stringify({ dataBase64 }) }),
  identify: (input: { mediaId: string; placeName: string; observedAt: string; habitat: string }) =>
    request<IdentificationResult>('/identify/image', { method: 'POST', body: JSON.stringify(input) }),
  confirm: (requestId: string, speciesId: string, observation: Record<string, unknown>) =>
    request<{ ok: boolean; observationId?: string }>(`/identify/${encodeURIComponent(requestId)}/confirm`, {
      method: 'POST', body: JSON.stringify({ speciesId, observation }),
    }),
}

export function friendlyApiError(error: unknown): string {
  if (!(error instanceof ApiError)) return '网络连接失败，请检查演示服务后重试。'
  const messages: Record<string, string> = {
    AUTH_REQUIRED: '演示会话已过期，请重新进入。',
    NOT_FOUND: '当前后端尚未启用比赛快捷登录。',
    QUOTA_EXCEEDED: '今日 AI 识别次数已用完。',
    MEDIA_REQUIRED: '照片尚未成功上传。',
    INVALID_IMAGE: '图片格式无效，请选择 JPEG、PNG 或 WebP。',
    PROVIDER_UNAVAILABLE: '华为云视觉服务暂不可用。',
  }
  const detail = messages[error.code] || `请求失败：${error.code}`
  return error.requestId ? `${detail}（请求 ${error.requestId}）` : detail
}
