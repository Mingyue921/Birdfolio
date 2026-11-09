import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CommunityPost, PostDraft } from '../models/BirdModels';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistedPayload } from '../models/PersistenceModels';
import { MediaAssetService } from '../media/MediaAssetService';

const STORE_NAME = 'birdfolio_community';
const POSTS_KEY = 'posts';
const DRAFTS_KEY = 'drafts';

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
      if (rows.length > 0) return CommunityStorage.parseDraftRows(rows);
      if (await BirdfolioDatabase.isMigrated(context, DRAFTS_KEY)) return [];
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(DRAFTS_KEY, '');
      const drafts = typeof raw === 'string' ? CommunityStorage.parseDrafts(raw) : [];
      await CommunityStorage.saveDraftDatabase(context, drafts);
      return drafts;
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
      DRAFTS_KEY, 'postDraft', owners);
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

  private static parseDrafts(raw: string): PostDraft[] {
    if (!raw) return [];
    try { const value = JSON.parse(raw) as PostDraft[]; return Array.isArray(value) ? value : []; } catch (_error) { return []; }
  }

  private static timestamp(value: string): number {
    const numeric = Number(value); if (Number.isFinite(numeric) && numeric > 0) return numeric;
    const parsed = Date.parse(value); return Number.isFinite(parsed) ? parsed : Date.now();
  }

  private static async loadDraftsLegacy(context: common.UIAbilityContext): Promise<PostDraft[]> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); const raw = await store.get(DRAFTS_KEY, ''); return typeof raw === 'string' ? CommunityStorage.parseDrafts(raw) : []; } catch (_error) { return []; }
  }

  private static async saveDraftsLegacy(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<boolean> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); await store.put(DRAFTS_KEY, JSON.stringify(drafts)); await store.flush(); return true; } catch (_error) { return false; }
  }
}
