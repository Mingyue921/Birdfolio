import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv, serverRoot } from '../config.mjs';
import { cleanupExpiredDemoAccounts } from '../demo-cleanup.mjs';
import { openDatabase } from '../database.mjs';
import { createMediaStorage } from '../platform/media-storage.mjs';
import { openPostgresDatabase } from '../platform/postgres.mjs';

export async function runDemoCleanup(options = {}) {
  const env = options.env || loadEnv(); const dataDir = resolve(options.dataDir || join(serverRoot, 'data')); let db; let storage;
  try {
    db = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase() === 'postgres' ? await (options.openPostgresDatabaseImpl || openPostgresDatabase)(env) : (options.openDatabaseImpl || openDatabase)(options.databasePath || databasePath(env, dataDir), { seed: false });
    storage = options.storage || await createMediaStorage(env, dataDir, options.mediaStorageOptions);
    return await cleanupExpiredDemoAccounts(db, { storage, logger: options.logger });
  } finally { await storage?.close?.(); await db?.close?.(); }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify({ event: 'demo.cleanup_result', ...await runDemoCleanup() })); }
  catch { console.error(JSON.stringify({ event: 'demo.cleanup_failed' })); process.exitCode = 1; }
}
