import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv, serverRoot } from '../config.mjs';
import { openDatabase } from '../database.mjs';
import { cleanupExpiredMedia } from '../media-cleanup.mjs';

export function runMediaCleanup(options = {}) {
  const env = options.env || loadEnv();
  const dataDir = resolve(options.dataDir || join(serverRoot, 'data'));
  let db;
  let failed = false;
  try {
    db = (options.openDatabaseImpl || openDatabase)(options.databasePath || databasePath(env, dataDir), {
      seed: false, logger: options.logger
    });
    return (options.cleanupImpl || cleanupExpiredMedia)(db, { logger: options.logger });
  } catch (error) {
    failed = true;
    throw error;
  } finally {
    if (db) {
      try { db.close(); }
      catch (error) { if (!failed) throw error; }
    }
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try {
    const result = runMediaCleanup();
    console.log(JSON.stringify({ event: 'media.cleanup_result', ...result }));
  } catch {
    console.error(JSON.stringify({ event: 'media.cleanup_failed' }));
    process.exitCode = 1;
  }
}
