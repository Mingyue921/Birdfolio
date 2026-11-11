export interface Session {
  accessToken: string
  refreshToken: string
  expiresAt?: number
  user?: { id: string; email?: string; displayName?: string }
}

export interface IdentificationCandidate {
  speciesId: string
  name: string
  scientificName?: string
  category?: string
  description?: string
  modelScore: number
  contextScore: number
  finalScore: number
  reasons: string[]
  inCatalog?: boolean
}

export interface IdentificationResult {
  requestId: string
  mediaId: string
  status: 'provider_success' | 'transport_error' | 'provider_error' | 'quota_exceeded' | 'unavailable'
  mode: string
  candidates: IdentificationCandidate[]
  warning?: string
  provider?: string
  modelVersion?: string
  cacheHit?: boolean
  elapsedMs?: number
}

export interface Observation {
  id: string
  speciesId?: string
  speciesName?: string
  name?: string
  observedAt?: string
  date?: string
  placeName?: string
  locationName?: string
  habitat?: string
  notes?: string
  count?: number
  updatedAt?: string
  createdAt?: string
  fuzzyLocation?: boolean
  [key: string]: unknown
}
