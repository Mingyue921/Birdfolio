import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { CommunityPost, PostDraft } from '../models/BirdModels';

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
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(DRAFTS_KEY, '');
      return typeof raw === 'string' && raw.length > 0 ? JSON.parse(raw) as PostDraft[] : [];
    } catch (_error) { return []; }
  }

  static async saveDrafts(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(DRAFTS_KEY, JSON.stringify(drafts));
      await store.flush();
      return true;
    } catch (_error) { return false; }
  }
}
