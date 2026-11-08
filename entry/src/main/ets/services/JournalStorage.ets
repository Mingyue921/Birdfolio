import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { JournalBook } from '../models/BirdModels';
import { JournalService } from './JournalService';

const STORE_NAME = 'birdfolio_journals';
const BOOKS_KEY = 'books';

export class JournalStorage {
  static async load(context: common.UIAbilityContext): Promise<JournalBook[]> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); const raw = await store.get(BOOKS_KEY, ''); return typeof raw === 'string' ? JournalService.parse(raw) : []; } catch (_error) { return []; }
  }

  static async save(context: common.UIAbilityContext, books: JournalBook[]): Promise<boolean> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); await store.put(BOOKS_KEY, JSON.stringify(books)); await store.flush(); return true; } catch (_error) { return false; }
  }
}
