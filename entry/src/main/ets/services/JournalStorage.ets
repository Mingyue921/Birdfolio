import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { JournalBook } from '../models/BirdModels';
import { JournalService } from './JournalService';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistedPayload } from '../models/PersistenceModels';
import { MediaAssetService } from '../media/MediaAssetService';

const STORE_NAME = 'birdfolio_journals';
const BOOKS_KEY = 'books';
const BOOKS_MIGRATION_KEY = 'books-v2';

export class JournalStorage {
  static async load(context: common.UIAbilityContext): Promise<JournalBook[]> {
    try {
      const rows = await BirdfolioDatabase.loadPayloads(context, 'journal_books');
      const current = JournalStorage.parseRows(rows);
      if (!await BirdfolioDatabase.isMigrated(context, BOOKS_MIGRATION_KEY)) {
        const legacy = await JournalStorage.loadLegacy(context);
        const recovered = JournalStorage.merge(current, legacy);
        await JournalStorage.saveDatabase(context, recovered);
        return recovered;
      }
      return current;
    } catch (_error) { return await JournalStorage.loadLegacy(context); }
  }

  static async save(context: common.UIAbilityContext, books: JournalBook[]): Promise<boolean> {
    try { await JournalStorage.saveDatabase(context, books); return true; }
    catch (_error) { return await JournalStorage.saveLegacy(context, books); }
  }

  private static async saveDatabase(context: common.UIAbilityContext, books: JournalBook[]): Promise<void> {
    const prepared = await MediaAssetService.prepareJournals(context, books);
    const rows: PersistedPayload[] = prepared.map((book: JournalBook): PersistedPayload => ({
      id: book.id, payload: JSON.stringify(book), updatedAt: JournalStorage.timestamp(book.updatedAt)
    }));
    const owners = MediaAssetService.journalReferences(prepared);
    await BirdfolioDatabase.replacePayloadsReferencesAndMarkMigrated(context, 'journal_books', rows,
      BOOKS_MIGRATION_KEY, 'journal', owners);
    prepared.forEach((saved: JournalBook, index: number) => {
      books[index].pages = saved.pages;
      books[index].coverImageUri = saved.coverImageUri;
    });
  }

  private static parseRows(rows: PersistedPayload[]): JournalBook[] {
    const books: JournalBook[] = [];
    rows.forEach((row: PersistedPayload) => {
      try { const parsed = JSON.parse(row.payload) as JournalBook; if (parsed && parsed.id) books.push(parsed); } catch (_error) {}
    });
    return books;
  }

  private static merge(current: JournalBook[], legacy: JournalBook[]): JournalBook[] {
    const merged = legacy.slice();
    current.forEach((item: JournalBook) => {
      const index = merged.findIndex((candidate: JournalBook) => candidate.id === item.id);
      if (index >= 0) merged[index] = item; else merged.push(item);
    });
    return merged;
  }

  private static timestamp(value: string): number {
    const numeric = Number(value); if (Number.isFinite(numeric) && numeric > 0) return numeric;
    const parsed = Date.parse(value); return Number.isFinite(parsed) ? parsed : Date.now();
  }

  private static async loadLegacy(context: common.UIAbilityContext): Promise<JournalBook[]> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); const raw = await store.get(BOOKS_KEY, ''); return typeof raw === 'string' ? JournalService.parse(raw) : []; } catch (_error) { return []; }
  }

  private static async saveLegacy(context: common.UIAbilityContext, books: JournalBook[]): Promise<boolean> {
    try { const store = await preferences.getPreferences(context, { name: STORE_NAME }); await store.put(BOOKS_KEY, JSON.stringify(books)); await store.flush(); return true; } catch (_error) { return false; }
  }
}
