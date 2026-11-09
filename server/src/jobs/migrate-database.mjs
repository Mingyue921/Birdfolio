import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv, serverRoot } from '../config.mjs';
import { openDatabase } from '../database.mjs';
import { openPostgresDatabase } from '../platform/postgres.mjs';
import { migratePostgres } from '../platform/postgres-migrations.mjs';

export async function runDatabaseMigrations(options = {}) {
  const env = options.env || loadEnv(); const dataDir = resolve(options.dataDir || join(serverRoot, 'data'));
  const provider = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase(); let db;
  try {
    if (provider === 'postgres') {
      db = await (options.openPostgresDatabaseImpl || openPostgresDatabase)(env);
      await (options.migratePostgresImpl || migratePostgres)(db, { logger: options.logger });
    } else db = (options.openDatabaseImpl || openDatabase)(options.databasePath || databasePath(env, dataDir), { seed: false, logger: options.logger });
    return { ok: true, provider };
  } finally { await db?.close?.(); }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify({ event: 'database.migrated', ...await runDatabaseMigrations() })); }
  catch { console.error(JSON.stringify({ event: 'database.migration_failed' })); process.exitCode = 1; }
}
