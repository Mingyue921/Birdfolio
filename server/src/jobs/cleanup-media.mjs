import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv, serverRoot } from '../config.mjs';
import { openDatabase } from '../database.mjs';
import { cleanupExpiredMedia } from '../media-cleanup.mjs';
import { openPostgresDatabase } from '../platform/postgres.mjs';
import { createMediaStorage } from '../platform/media-storage.mjs';

export async function runMediaCleanup(options = {}) {
  const env = options.env || loadEnv();
  const dataDir = resolve(options.dataDir || join(serverRoot, 'data'));
  let db;
  let failed = false;
  try {
    db = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase() === 'postgres'
      ? await (options.openPostgresDatabaseImpl || openPostgresDatabase)(env)
      : (options.openDatabaseImpl || openDatabase)(options.databasePath || databasePath(env, dataDir), { seed: false, logger: options.logger });
    const storage = options.storage || await createMediaStorage(env, dataDir, options.mediaStorageOptions);
    return await (options.cleanupImpl || cleanupExpiredMedia)(db, { logger: options.logger, storage });
  } catch (error) {
    failed = true;
    throw error;
  } finally {
    if (db) {
      try { await db.close(); }
      catch (error) { if (!failed) throw error; }
    }
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const result = await runMediaCleanup();
    console.log(JSON.stringify({ event: 'media.cleanup_result', ...result }));
  } catch {
    console.error(JSON.stringify({ event: 'media.cleanup_failed' }));
    process.exitCode = 1;
  }
}
