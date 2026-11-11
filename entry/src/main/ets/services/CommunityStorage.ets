import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CommunityPost, PostDraft } from '../models/BirdModels';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistedPayload } from '../models/PersistenceModels';
import { MediaAssetService } from '../media/MediaAssetService';
import { LegacyPreferencesReader } from './LegacyPreferencesReader';

const STORE_NAME = 'birdfolio_community';
const POSTS_KEY = 'posts';
const DRAFTS_KEY = 'drafts';
const DRAFTS_MIGRATION_KEY = 'drafts-v3';

export class CommunityStorage {
  static async loadPosts(context: common.UIAbilityContext): Promise<CommunityPost[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(POSTS_KEY, '');
      return typeof raw === 'string' && raw.length > 0 ? JSON.parse(raw) as CommunityPost[] : [];
    } catch (_error) { return []; }
  }

  static async savePosts(context: common.UIAbilityContext, posts: CommunityPost[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(POSTS_KEY, JSON.stringify(posts));
      await store.flush();
      return true;
    } catch (_error) { return false; }
  }

  static async loadDrafts(context: common.UIAbilityContext): Promise<PostDraft[]> {
    try {
      const rows = await BirdfolioDatabase.loadPayloads(context, 'post_drafts');
      const current = CommunityStorage.parseDraftRows(rows);
      if (!await BirdfolioDatabase.isMigrated(context, DRAFTS_MIGRATION_KEY)) {
        const legacy = await CommunityStorage.loadDraftsLegacy(context);
        const recovered = CommunityStorage.mergeDrafts(current, legacy);
        await CommunityStorage.saveDraftDatabase(context, recovered);
        return recovered;
      }
      return current;
    } catch (_error) { return await CommunityStorage.loadDraftsLegacy(context); }
  }

  static async saveDrafts(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<boolean> {
    try { await CommunityStorage.saveDraftDatabase(context, drafts); return true; }
    catch (_error) { return await CommunityStorage.saveDraftsLegacy(context, drafts); }
  }

  private static async saveDraftDatabase(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<void> {
    const prepared = await MediaAssetService.preparePostDrafts(context, drafts);
    const rows: PersistedPayload[] = prepared.map((draft: PostDraft): PersistedPayload => ({
      id: draft.id, payload: JSON.stringify(draft), updatedAt: CommunityStorage.timestamp(draft.updatedAt)
    }));
    const owners = MediaAssetService.postDraftReferences(prepared);
    await BirdfolioDatabase.replacePayloadsReferencesAndMarkMigrated(context, 'post_drafts', rows,
      DRAFTS_MIGRATION_KEY, 'postDraft', owners);
    prepared.forEach((saved: PostDraft, index: number) => {
      drafts[index].imageUri = saved.imageUri;
      drafts[index].imageAssetId = saved.imageAssetId;
    });
  }

  private static parseDraftRows(rows: PersistedPayload[]): PostDraft[] {
    const drafts: PostDraft[] = [];
    rows.forEach((row: PersistedPayload) => { try { const draft = JSON.parse(row.payload) as PostDraft; if (draft && draft.id) drafts.push(draft); } catch (_error) {} });
    return drafts;
  }

  private static mergeDrafts(current: PostDraft[], legacy: PostDraft[]): PostDraft[] {
    const merged = legacy.slice();
    current.forEach((item: PostDraft) => {
      const index = merged.findIndex((candidate: PostDraft) => candidate.id === item.id);
      if (index >= 0) merged[index] = item; else merged.push(item);
    });
    return merged;
  }

  private static parseDrafts(raw: string): PostDraft[] {
    if (!raw) return [];
    try { const value = JSON.parse(raw) as PostDraft[]; return Array.isArray(value) ? value : []; } catch (_error) { return []; }
  }

  private static timestamp(value: string): number {
    const numeric = Number(value); if (Number.isFinite(numeric) && numeric > 0) return numeric;
    const parsed = Date.parse(value); return Number.isFinite(parsed) ? parsed : Date.now();
  }

  private static async loadDraftsLegacy(context: common.UIAbilityContext): Promise<PostDraft[]> {
    let raw = '';
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); const stored = await store.get(DRAFTS_KEY, ''); if (typeof stored === 'string') raw = stored; } catch (_error) {}
    if (raw.length === 0) raw = LegacyPreferencesReader.readString(context, STORE_NAME, DRAFTS_KEY);
    return raw.length > 0 ? CommunityStorage.parseDrafts(raw) : [];
  }

  private static async saveDraftsLegacy(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<boolean> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); await store.put(DRAFTS_KEY, JSON.stringify(drafts)); await store.flush(); return true; } catch (_error) { return false; }
  }
}
