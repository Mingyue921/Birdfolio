import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { MediaAsset } from '../models/BirdModels';
import { MediaReference, PersistedPayload } from '../models/PersistenceModels';
import { PersistencePolicy } from './PersistencePolicy';

export type PayloadTable = 'observations' | 'journal_books' | 'sync_jobs' | 'post_drafts';

const DATABASE_NAME = 'birdfolio_local.db';
const DATABASE_VERSION = PersistencePolicy.DATABASE_VERSION;

const CREATE_SCHEMA: string[] = [
  `CREATE TABLE IF NOT EXISTS migration_state(key TEXT PRIMARY KEY, completed_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS observations(
    id TEXT PRIMARY KEY, payload TEXT NOT NULL, species_id TEXT NOT NULL DEFAULT '',
    observed_at TEXT NOT NULL DEFAULT '', place_name TEXT NOT NULL DEFAULT '',
    updated_at INTEGER NOT NULL, deleted_at INTEGER NOT NULL DEFAULT 0,
    version INTEGER NOT NULL DEFAULT 1, sync_status TEXT NOT NULL DEFAULT 'local')`,
  `CREATE INDEX IF NOT EXISTS observations_observed_at ON observations(observed_at DESC)`,
  `CREATE INDEX IF NOT EXISTS observations_species_id ON observations(species_id)`,
  `CREATE TABLE IF NOT EXISTS journal_books(
    id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS sync_jobs(
    id TEXT PRIMARY KEY, payload TEXT NOT NULL, entity_id TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending', updated_at INTEGER NOT NULL)`,
  `CREATE INDEX IF NOT EXISTS sync_jobs_status ON sync_jobs(status, updated_at)`,
  `CREATE TABLE IF NOT EXISTS post_drafts(
    id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)`,
  `CREATE TABLE IF NOT EXISTS media_assets(
    id TEXT PRIMARY KEY, original_uri TEXT NOT NULL, thumbnail_uri TEXT NOT NULL,
    preview_uri TEXT NOT NULL, mime_type TEXT NOT NULL, byte_size INTEGER NOT NULL,
    width INTEGER NOT NULL, height INTEGER NOT NULL, sha256 TEXT NOT NULL,
    created_at INTEGER NOT NULL, orphaned_at INTEGER NOT NULL DEFAULT 0)`,
  `CREATE UNIQUE INDEX IF NOT EXISTS media_assets_sha256 ON media_assets(sha256)`,
  `CREATE TABLE IF NOT EXISTS media_references(
    asset_id TEXT NOT NULL, owner_type TEXT NOT NULL, owner_id TEXT NOT NULL,
    created_at INTEGER NOT NULL, PRIMARY KEY(asset_id, owner_type, owner_id),
    FOREIGN KEY(asset_id) REFERENCES media_assets(id) ON DELETE CASCADE)`,
  `CREATE INDEX IF NOT EXISTS media_references_owner ON media_references(owner_type, owner_id)`
];

export class BirdfolioDatabase {
  private static stores: Map<string, relationalStore.RdbStore> = new Map<string, relationalStore.RdbStore>();

  static async open(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const key = context.databaseDir || DATABASE_NAME;
    const cached = BirdfolioDatabase.stores.get(key);
    if (cached) return cached;
    const config: relationalStore.StoreConfig = { name: DATABASE_NAME, securityLevel: relationalStore.SecurityLevel.S1 };
    const store = await relationalStore.getRdbStore(context, config);
    await BirdfolioDatabase.ensureSchema(store);
    BirdfolioDatabase.stores.set(key, store);
    return store;
  }

  static async clear(context: common.UIAbilityContext): Promise<void> {
    const key = context.databaseDir || DATABASE_NAME;
    const cached = BirdfolioDatabase.stores.get(key);
    if (cached) {
      await cached.close();
      BirdfolioDatabase.stores.delete(key);
    }
    await relationalStore.deleteRdbStore(context, DATABASE_NAME);
  }

  static async loadPayloads(context: common.UIAbilityContext, table: PayloadTable): Promise<PersistedPayload[]> {
    const store = await BirdfolioDatabase.open(context);
    const predicates = new relationalStore.RdbPredicates(table); predicates.orderByDesc('updated_at');
    const result = await store.query(predicates, ['id', 'payload', 'updated_at']);
    const values: PersistedPayload[] = [];
    try {
      if (result.rowCount > 0 && result.goToFirstRow()) {
        do { values.push({ id: result.getString(result.getColumnIndex('id')), payload: result.getString(result.getColumnIndex('payload')), updatedAt: result.getLong(result.getColumnIndex('updated_at')) }); } while (result.goToNextRow());
      }
    } finally { result.close(); }
    return values;
  }

  static async replacePayloads(context: common.UIAbilityContext, table: PayloadTable, values: PersistedPayload[]): Promise<void> {
    const store = await BirdfolioDatabase.open(context); store.beginTransaction();
    try {
      await store.executeSql('DELETE FROM ' + table);
      for (const item of values) await BirdfolioDatabase.insertPayload(store, table, item);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }

  static async replacePayloadsAndMarkMigrated(context: common.UIAbilityContext, table: PayloadTable,
    values: PersistedPayload[], migrationKey: string): Promise<void> {
    const store = await BirdfolioDatabase.open(context); store.beginTransaction();
    try {
      await store.executeSql('DELETE FROM ' + table);
      for (const item of values) await BirdfolioDatabase.insertPayload(store, table, item);
      await store.executeSql('INSERT OR REPLACE INTO migration_state(key,completed_at) VALUES(?,?)', [migrationKey, Date.now()]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }

  static async replacePayloadsReferencesAndMarkMigrated(context: common.UIAbilityContext, table: PayloadTable,
    values: PersistedPayload[], migrationKey: string, ownerType: string, owners: Map<string, string[]>): Promise<void> {
    const store = await BirdfolioDatabase.open(context); store.beginTransaction();
    try {
      await store.executeSql('DELETE FROM ' + table);
      for (const item of values) await BirdfolioDatabase.insertPayload(store, table, item);
      await BirdfolioDatabase.replaceMediaReferencesInStore(store, ownerType, owners);
      await store.executeSql('INSERT OR REPLACE INTO migration_state(key,completed_at) VALUES(?,?)', [migrationKey, Date.now()]);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }

  static async isMigrated(context: common.UIAbilityContext, key: string): Promise<boolean> {
    const store = await BirdfolioDatabase.open(context);
    const predicates = new relationalStore.RdbPredicates('migration_state'); predicates.equalTo('key', key);
    const result = await store.query(predicates, ['key']);
    try { return result.rowCount > 0; } finally { result.close(); }
  }

  static async markMigrated(context: common.UIAbilityContext, key: string): Promise<void> {
    const store = await BirdfolioDatabase.open(context);
    await store.executeSql('INSERT OR REPLACE INTO migration_state(key,completed_at) VALUES(?,?)', [key, Date.now()]);
  }

  static async saveMediaAsset(context: common.UIAbilityContext, asset: MediaAsset): Promise<void> {
    const store = await BirdfolioDatabase.open(context);
    await store.executeSql(`INSERT OR REPLACE INTO media_assets(
      id,original_uri,thumbnail_uri,preview_uri,mime_type,byte_size,width,height,sha256,created_at,orphaned_at)
      VALUES(?,?,?,?,?,?,?,?,?,?,COALESCE((SELECT orphaned_at FROM media_assets WHERE id=?),?))`,
    [asset.id, asset.originalUri, asset.thumbnailUri, asset.previewUri, asset.mimeType, asset.byteSize,
      asset.width, asset.height, asset.sha256, asset.createdAt, asset.id, asset.createdAt]);
  }

  static async findMediaAssetByHash(context: common.UIAbilityContext, sha256: string): Promise<MediaAsset | null> {
    return BirdfolioDatabase.findMedia(context, 'sha256', sha256);
  }

  static async findMediaAsset(context: common.UIAbilityContext, id: string): Promise<MediaAsset | null> {
    return BirdfolioDatabase.findMedia(context, 'id', id);
  }

  static async addMediaReference(context: common.UIAbilityContext, reference: MediaReference): Promise<void> {
    const store = await BirdfolioDatabase.open(context);
    await store.executeSql('INSERT OR REPLACE INTO media_references(asset_id,owner_type,owner_id,created_at) VALUES(?,?,?,?)',
      [reference.assetId, reference.ownerType, reference.ownerId, reference.createdAt]);
    await store.executeSql('UPDATE media_assets SET orphaned_at=0 WHERE id=?', [reference.assetId]);
  }

  static async removeMediaReference(context: common.UIAbilityContext, assetId: string, ownerType: string, ownerId: string): Promise<void> {
    const store = await BirdfolioDatabase.open(context);
    await store.executeSql('DELETE FROM media_references WHERE asset_id=? AND owner_type=? AND owner_id=?', [assetId, ownerType, ownerId]);
    await store.executeSql(`UPDATE media_assets SET orphaned_at=? WHERE id=? AND NOT EXISTS(
      SELECT 1 FROM media_references WHERE asset_id=?)`, [Date.now(), assetId, assetId]);
  }

  static async replaceMediaReferences(context: common.UIAbilityContext, ownerType: string,
    owners: Map<string, string[]>): Promise<void> {
    const store = await BirdfolioDatabase.open(context); store.beginTransaction();
    try {
      await BirdfolioDatabase.replaceMediaReferencesInStore(store, ownerType, owners);
      store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }

  static async orphanedMedia(context: common.UIAbilityContext, olderThan: number): Promise<MediaAsset[]> {
    const store = await BirdfolioDatabase.open(context);
    const predicates = new relationalStore.RdbPredicates('media_assets');
    predicates.greaterThan('orphaned_at', 0); predicates.lessThanOrEqualTo('orphaned_at', olderThan);
    const result = await store.query(predicates); const assets: MediaAsset[] = [];
    try {
      if (result.rowCount > 0 && result.goToFirstRow()) {
        do { assets.push(BirdfolioDatabase.mediaAssetFromResult(result)); } while (result.goToNextRow());
      }
    } finally { result.close(); }
    return assets;
  }

  static async deleteMediaAsset(context: common.UIAbilityContext, id: string): Promise<void> {
    const store = await BirdfolioDatabase.open(context);
    const predicates = new relationalStore.RdbPredicates('media_assets'); predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    if (store.version >= DATABASE_VERSION) return;
    store.beginTransaction();
    try {
      for (const sql of CREATE_SCHEMA) await store.executeSql(sql);
      store.version = DATABASE_VERSION; store.commit();
    } catch (error) { store.rollBack(); throw new Error(String(error)); }
  }

  private static async insertPayload(store: relationalStore.RdbStore, table: PayloadTable, item: PersistedPayload): Promise<void> {
    if (table === 'observations') {
      let speciesId = ''; let observedAt = ''; let placeName = ''; let version = 1; let syncStatus = 'local';
      try {
        const parsed = JSON.parse(item.payload) as Record<string, Object>;
        speciesId = String(parsed['speciesId'] || ''); observedAt = String(parsed['observedAt'] || ''); placeName = String(parsed['placeName'] || '');
        const meta = parsed['localMeta'] as Record<string, Object> | undefined;
        if (meta) { version = Number(meta['version'] || 1); syncStatus = String(meta['syncStatus'] || 'local'); }
      } catch (_error) {}
      await store.executeSql(`INSERT OR REPLACE INTO observations(id,payload,species_id,observed_at,place_name,updated_at,version,sync_status)
        VALUES(?,?,?,?,?,?,?,?)`, [item.id, item.payload, speciesId, observedAt, placeName, item.updatedAt, version, syncStatus]); return;
    }
    if (table === 'sync_jobs') {
      let entityId = ''; let status = 'pending';
      try { const parsed = JSON.parse(item.payload) as Record<string, Object>; entityId = String(parsed['entityId'] || ''); status = String(parsed['status'] || 'pending'); } catch (_error) {}
      await store.executeSql('INSERT OR REPLACE INTO sync_jobs(id,payload,entity_id,status,updated_at) VALUES(?,?,?,?,?)', [item.id, item.payload, entityId, status, item.updatedAt]); return;
    }
    await store.executeSql('INSERT OR REPLACE INTO ' + table + '(id,payload,updated_at) VALUES(?,?,?)', [item.id, item.payload, item.updatedAt]);
  }

  private static async replaceMediaReferencesInStore(store: relationalStore.RdbStore, ownerType: string,
    owners: Map<string, string[]>): Promise<void> {
    const previous = await store.querySql('SELECT DISTINCT asset_id FROM media_references WHERE owner_type=?', [ownerType]);
    const previousIds: string[] = [];
    try {
      if (previous.rowCount > 0 && previous.goToFirstRow()) {
        do { previousIds.push(previous.getString(previous.getColumnIndex('asset_id'))); } while (previous.goToNextRow());
      }
    } finally { previous.close(); }
    await store.executeSql('DELETE FROM media_references WHERE owner_type=?', [ownerType]);
    for (const owner of owners.entries()) {
      for (const assetId of owner[1]) {
        await store.executeSql('INSERT OR IGNORE INTO media_references(asset_id,owner_type,owner_id,created_at) VALUES(?,?,?,?)',
          [assetId, ownerType, owner[0], Date.now()]);
        await store.executeSql('UPDATE media_assets SET orphaned_at=0 WHERE id=?', [assetId]);
      }
    }
    for (const assetId of previousIds) {
      await store.executeSql(`UPDATE media_assets SET orphaned_at=? WHERE id=? AND NOT EXISTS(
        SELECT 1 FROM media_references WHERE asset_id=?)`, [Date.now(), assetId, assetId]);
    }
  }

  private static async findMedia(context: common.UIAbilityContext, column: string, value: string): Promise<MediaAsset | null> {
    const store = await BirdfolioDatabase.open(context);
    const predicates = new relationalStore.RdbPredicates('media_assets'); predicates.equalTo(column, value);
    const result = await store.query(predicates);
    try { if (result.rowCount === 0 || !result.goToFirstRow()) return null; return BirdfolioDatabase.mediaAssetFromResult(result); } finally { result.close(); }
  }

  private static mediaAssetFromResult(result: relationalStore.ResultSet): MediaAsset {
    return { id: result.getString(result.getColumnIndex('id')), originalUri: result.getString(result.getColumnIndex('original_uri')),
      thumbnailUri: result.getString(result.getColumnIndex('thumbnail_uri')), previewUri: result.getString(result.getColumnIndex('preview_uri')),
      mimeType: result.getString(result.getColumnIndex('mime_type')), byteSize: result.getLong(result.getColumnIndex('byte_size')),
      width: result.getLong(result.getColumnIndex('width')), height: result.getLong(result.getColumnIndex('height')),
      sha256: result.getString(result.getColumnIndex('sha256')), createdAt: result.getLong(result.getColumnIndex('created_at')) };
  }
}
