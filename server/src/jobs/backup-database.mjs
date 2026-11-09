import { execFileSync } from 'node:child_process';
import { copyFileSync, mkdirSync } from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv, serverRoot } from '../config.mjs';
import { openDatabase } from '../database.mjs';

function outputArgument(argv) { const value = argv.find(item => item.startsWith('--output=')); return value ? resolve(value.slice(9)) : ''; }

export async function backupDatabase(options = {}) {
  const env = options.env || loadEnv(); const provider = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase();
  const stamp = new Date().toISOString().replace(/[:.]/g, '-'); const extension = provider === 'postgres' ? 'dump' : 'db';
  const output = options.output || outputArgument(options.argv || process.argv.slice(2)) || join(serverRoot, 'backups', `birdfolio-${stamp}.${extension}`);
  mkdirSync(dirname(output), { recursive: true });
  if (provider === 'postgres') {
    if (!String(env.DATABASE_URL || '').trim()) throw new Error('DATABASE_URL_REQUIRED');
    (options.execFileImpl || execFileSync)(env.PG_DUMP_BIN || 'pg_dump', ['--format=custom', '--no-owner', '--no-privileges', `--file=${output}`, env.DATABASE_URL], { stdio: 'inherit' });
  } else {
    const source = options.databasePath || databasePath(env); const db = (options.openDatabaseImpl || openDatabase)(source, { seed: false });
    try { db.exec('PRAGMA wal_checkpoint(TRUNCATE)'); } finally { db.close(); }
    copyFileSync(source, output);
  }
  return { ok: true, provider, file: basename(output), output };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify({ event: 'database.backup_completed', ...await backupDatabase() })); }
  catch { console.error(JSON.stringify({ event: 'database.backup_failed' })); process.exitCode = 1; }
}
