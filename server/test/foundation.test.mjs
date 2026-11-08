import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { openDatabase } from '../src/database.mjs';
import { cleanupExpiredMedia } from '../src/media-cleanup.mjs';

const silentLogger = { info() {}, warn() {}, error() {} };

test('numbered migrations upgrade a legacy database once and preserve data', () => {
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
    { version: 2, name: 'observation_version' }
  ]);
  assert.ok(db.prepare('PRAGMA table_info(observations)').all().some(column => column.name === 'version'));
  assert.equal(db.prepare('SELECT payload,version FROM observations WHERE id=?').get('legacy-observation').version, 1);
  db.close();

  const reopened = openDatabase(path, { seed: false, logger: silentLogger });
  assert.equal(reopened.prepare('SELECT COUNT(*) AS count FROM schema_migrations').get().count, 2);
  assert.equal(reopened.prepare('SELECT COUNT(*) AS count FROM observations').get().count, 1);
  reopened.close();
  rmSync(dir, { recursive: true, force: true });
});

test('expired media cleanup removes only unreferenced files', () => {
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

  assert.deepEqual(cleanupExpiredMedia(db, { now, logger: silentLogger }), { scanned: 1, removed: 1 });
  assert.equal(existsSync(expiredPath), false);
  assert.equal(existsSync(referencedPath), true);
  assert.equal(existsSync(activePath), true);
  assert.equal(db.prepare('SELECT deleted_at FROM media WHERE id=?').get('media-expired').deleted_at, now);
  assert.equal(db.prepare('SELECT deleted_at FROM media WHERE id=?').get('media-referenced').deleted_at, 0);
  db.close();
  rmSync(dir, { recursive: true, force: true });
});
