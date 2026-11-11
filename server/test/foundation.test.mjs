import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { openDatabase } from '../src/database.mjs';
import { cleanupExpiredMedia } from '../src/media-cleanup.mjs';
import { migrateDatabase } from '../src/migrations.mjs';

const silentLogger = { info() {}, warn() {}, error() {} };

test('empty database applies numbered migrations in order and reopening is idempotent', () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-empty-migration-'));
  const path = join(dir, 'empty.db');
  const db = openDatabase(path, { seed: false, logger: silentLogger });
  assert.deepEqual(db.prepare('SELECT version FROM schema_migrations ORDER BY version').all().map(row => row.version), [1, 2, 3, 4]);
  db.close();
  const reopened = openDatabase(path, { seed: false, logger: silentLogger });
  assert.deepEqual(reopened.prepare('SELECT version FROM schema_migrations ORDER BY version').all().map(row => row.version), [1, 2, 3, 4]);
  reopened.close();
  rmSync(dir, { recursive: true, force: true });
});

test('numbered migrations upgrade a legacy database and preserve data', () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-migration-'));
  const path = join(dir, 'legacy.db');
  const legacy = new DatabaseSync(path);
  legacy.exec(`CREATE TABLE observations (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL,
    updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL DEFAULT ''
  )`);
  legacy.prepare('INSERT INTO observations(id,user_id,payload,updated_at,deleted_at) VALUES(?,?,?,?,?)')
    .run('legacy-observation', 'legacy-user', '{"note":"preserved"}', '1000', '');
  legacy.close();

  const db = openDatabase(path, { seed: false, logger: silentLogger });
  const applied = db.prepare('SELECT version,name FROM schema_migrations ORDER BY version').all()
    .map(row => ({ version: row.version, name: row.name }));
  assert.deepEqual(applied, [
    { version: 1, name: 'initial_schema' },
    { version: 2, name: 'observation_version' },
    { version: 3, name: 'persistent_rate_limits' },
    { version: 4, name: 'competition_demo_accounts' }
  ]);
  assert.ok(db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='rate_limits'").get());
  assert.ok(db.prepare('PRAGMA table_info(observations)').all().some(column => column.name === 'version'));
  assert.equal(db.prepare('SELECT payload,version FROM observations WHERE id=?').get('legacy-observation').version, 1);
  db.close();

  const reopened = openDatabase(path, { seed: false, logger: silentLogger });
  assert.equal(reopened.prepare('SELECT COUNT(*) AS count FROM schema_migrations').get().count, 4);
  assert.equal(reopened.prepare('SELECT COUNT(*) AS count FROM observations').get().count, 1);
  reopened.close();
  rmSync(dir, { recursive: true, force: true });
});

test('failed migration rolls back changes and does not advance schema version', () => {
  const db = new DatabaseSync(':memory:');
  const migrationList = [
    { version: 1, name: 'first', up(database) { database.exec('CREATE TABLE first_table(id INTEGER)'); } },
    { version: 2, name: 'failing', up(database) { database.exec('CREATE TABLE rolled_back(id INTEGER)'); throw new Error('EXPECTED_MIGRATION_FAILURE'); } }
  ];
  assert.throws(() => migrateDatabase(db, { migrationList, logger: silentLogger }), /EXPECTED_MIGRATION_FAILURE/);
  assert.deepEqual(db.prepare('SELECT version FROM schema_migrations ORDER BY version').all().map(row => row.version), [1]);
  assert.equal(db.prepare("SELECT COUNT(*) AS count FROM sqlite_master WHERE type='table' AND name='rolled_back'").get().count, 0);
  db.close();
});

test('database initialization failure closes the database without masking the error', () => {
  let closes = 0;
  const fakeDb = { exec() { throw new Error('PRAGMA_FAILED'); }, close() { closes += 1; throw new Error('CLOSE_FAILED'); } };
  assert.throws(() => openDatabase(join(tmpdir(), 'never-created.db'), { databaseFactory: () => fakeDb }), /PRAGMA_FAILED/);
  assert.equal(closes, 1);
});

test('expired media cleanup removes only unreferenced files', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'birdfolio-cleanup-'));
  const db = openDatabase(join(dir, 'cleanup.db'), { seed: false, logger: silentLogger });
  const expiredPath = join(dir, 'expired.png'); const referencedPath = join(dir, 'referenced.png'); const activePath = join(dir, 'active.png');
  writeFileSync(expiredPath, 'expired'); writeFileSync(referencedPath, 'referenced'); writeFileSync(activePath, 'active');
  const now = 10_000;
  const insertMedia = db.prepare(`INSERT INTO media(id,user_id,file_name,mime_type,byte_size,file_path,created_at,expires_at,deleted_at)
    VALUES(?,?,?,?,?,?,?,?,0)`);
  insertMedia.run('media-expired', 'user', 'media-expired.png', 'image/png', 7, expiredPath, 1, now - 1);
  insertMedia.run('media-referenced', 'user', 'media-referenced.png', 'image/png', 10, referencedPath, 1, now - 1);
  insertMedia.run('media-active', 'user', 'media-active.png', 'image/png', 6, activePath, 1, now + 1);
  db.prepare(`INSERT INTO posts(id,user_id,author_name,type,title,body,species_id,behavior,place_name,visibility,image_url,created_at,updated_at)
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`).run('post-media', 'user', 'user', 'photo', 'title', 'body', '', '', '', '所有人', '/media/media-referenced.png', 'now', 'now');

  const storage = { async deleteObject(key) { const row = db.prepare('SELECT file_path FROM media WHERE file_name=?').get(key); if (!row || !existsSync(row.file_path)) return true; rmSync(row.file_path); return true; } };
  assert.deepEqual(await cleanupExpiredMedia(db, { now, logger: silentLogger, storage }), { scanned: 3, removed: 1, skipped: 2 });
  assert.equal(existsSync(expiredPath), false);
  assert.equal(existsSync(referencedPath), true);
  assert.equal(existsSync(activePath), true);
  assert.equal(db.prepare('SELECT deleted_at FROM media WHERE id=?').get('media-expired').deleted_at, now);
  assert.equal(db.prepare('SELECT deleted_at FROM media WHERE id=?').get('media-referenced').deleted_at, 0);
  db.close();
  rmSync(dir, { recursive: true, force: true });
});
