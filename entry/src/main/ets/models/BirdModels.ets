export interface BirdSpecies {
  id: string;
  name: string;
  scientificName: string;
  aliases: string[];
  category: string;
  description: string;
  regions: string[];
  imageHint: string;
  features?: string[];
  gbifKey?: number;
  imageUrl?: string;
  imageCreator?: string;
  imageLicense?: string;
  imageSourceUrl?: string;
  sourceUrl?: string;
  dataSource?: string;
}

export interface SpeciesCatalogResult {
  source: string;
  query: string;
  items: BirdSpecies[];
  notice: string;
}

export interface Observation {
  id: string;
  userId: string;
  speciesId: string;
  count: number;
  observedAt: string;
  latitude: number;
  longitude: number;
  placeName: string;
  photos: string[];
  audioNote: string;
  note: string;
  fuzzyLocation: boolean;
  createdAt: string;
  behaviors?: string[];
  updatedAt?: string;
  locationSource?: 'current' | 'manual' | 'none';
  photoAssetIds?: string[];
  localMeta?: LocalEntityMeta;
}

export interface JournalEntry {
  id: string;
  observationId: string;
  templateId: string;
  text: string;
  stickers: string[];
  exportedImageUrl: string;
  updatedAt: string;
}

export interface JournalBook {
  id: string;
  title: string;
  observationIds: string[];
  templateId: string;
  pages: JournalPage[];
  status: 'draft' | 'completed';
  createdAt: string;
  updatedAt: string;
  coverImageUri?: string;
  editorVersion?: number;
}

export interface JournalPage {
  id: string;
  elements: JournalElement[];
  backgroundColor: string;
  updatedAt: string;
}

export interface JournalElement {
  id: string;
  type: 'text' | 'image' | 'sticker' | 'drawing' | 'observation';
  x: number;
  y: number;
  width: number;
  height: number;
  rotation: number;
  scale: number;
  zIndex: number;
  locked: boolean;
  visible?: boolean;
  name?: string;
  role?: 'title' | 'meta' | 'photo' | 'observation' | 'decoration' | 'user';
  content: string;
  assetId?: string;
  style?: JournalElementStyle;
}

export interface LocalEntityMeta {
  version: number;
  updatedAt: number;
  deletedAt?: number;
  syncStatus: 'local' | 'pending' | 'synced' | 'conflict';
}

export interface MediaAsset {
  id: string;
  originalUri: string;
  thumbnailUri: string;
  previewUri: string;
  mimeType: string;
  byteSize: number;
  width: number;
  height: number;
  sha256: string;
  createdAt: number;
}

export interface JournalElementStyle {
  fontSize?: number;
  fontFamily?: string;
  color?: string;
  backgroundColor?: string;
  strokeColor?: string;
  strokeWidth?: number;
  opacity?: number;
  fontWeight?: 'normal' | 'bold';
  fontStyle?: 'normal' | 'italic';
  textAlign?: 'left' | 'center' | 'right';
  lineHeight?: number;
  borderRadius?: number;
  imageFit?: 'contain';
}

export interface StickerAsset {
  id: string;
  name: string;
  category: string;
  imageUrl: string;
  free: boolean;
}

export interface TabItem {
  id: string;
  label: string;
}

export interface RoadmapPhase {
  id: string;
  title: string;
  status: 'active' | 'planned';
  summary: string;
  items: string[];
}

export interface DrawerItem {
  id: string;
  label: string;
  detail: string;
}

export interface ObservationInput {
  speciesId: string;
  countText: string;
  observedAt?: string;
  placeName: string;
  audioNote: string;
  note: string;
  fuzzyLocation: boolean;
  photos: string[];
  behaviors?: string[];
  latitude?: number;
  longitude?: number;
  locationSource?: 'current' | 'manual' | 'none';
  baseLatitude?: number;
  baseLongitude?: number;
  existingCount: number;
}

export interface ObservationDraft extends ObservationInput {}

export interface MonthlyObservationStat {
  month: number;
  count: number;
}

export interface SpeciesObservationStat {
  speciesId: string;
  count: number;
  ratio: number;
}

export interface PlaceObservationStat {
  placeName: string;
  recordCount: number;
  birdCount: number;
  latitude: number;
  longitude: number;
}

export interface YearStats {
  year: number;
  observations: number;
  speciesCount: number;
  birdCount: number;
  photoRecords: number;
  placeCount: number;
  monthly: MonthlyObservationStat[];
  species: SpeciesObservationStat[];
  places: PlaceObservationStat[];
}

export type BackendStatus = 'online' | 'offline' | 'syncing' | 'pending' | 'error';

export interface UserProfile {
  displayName: string;
  bio: string;
  avatarUri: string;
}

export interface CommunityPost {
  id: string;
  userId: string;
  authorName: string;
  type: 'photo' | 'journal';
  title: string;
  body: string;
  speciesId: string;
  behavior: string;
  placeName: string;
  visibility: string;
  imageUrl: string;
  createdAt: string;
  updatedAt: string;
  likeCount: number;
  favoriteCount: number;
  commentCount: number;
  liked?: boolean;
  favorited?: boolean;
}

export interface PostComment {
  id: string;
  postId: string;
  userId: string;
  authorName: string;
  body: string;
  createdAt: string;
}

export interface PostDraft {
  id: string;
  title: string;
  body: string;
  speciesId: string;
  behavior: string;
  placeName: string;
  visibility: string;
  type: 'photo' | 'journal';
  imageUri: string;
  imageAssetId?: string;
  updatedAt: string;
}

export interface CreatePostInput {
  /** Identity is derived from the authenticated session by the server. */
  userId?: string;
  authorName: string;
  type: 'photo' | 'journal';
  title: string;
  body: string;
  speciesId: string;
  behavior: string;
  placeName: string;
  visibility: string;
  imageBase64: string;
  mediaId?: string;
}

export interface IdentificationCandidate {
  speciesId: string;
  name: string;
  scientificName: string;
  aliases: string[];
  category: string;
  description: string;
  regions: string[];
  imageHint: string;
  inCatalog: boolean;
  modelScore: number;
  contextScore: number;
  finalScore: number;
  reasons: string[];
}

export interface IdentificationResult {
  mode: 'provider' | 'unavailable';
  candidates: IdentificationCandidate[];
  warning: string;
}

export interface HealthResult {
  ok: boolean;
  service: string;
  aiMode: string;
}
