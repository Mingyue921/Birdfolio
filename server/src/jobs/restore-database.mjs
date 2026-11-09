import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { databasePath, loadEnv } from '../config.mjs';

function sourceArgument(argv) { const value = argv.find(item => item.startsWith('--from=')); return value ? resolve(value.slice(7)) : ''; }

export async function restoreDatabase(options = {}) {
  const env = options.env || loadEnv();
  if (String(env.CONFIRM_RESTORE || '') !== 'RESTORE_BIRDFOLIO') throw new Error('RESTORE_CONFIRMATION_REQUIRED');
  const source = options.source || sourceArgument(options.argv || process.argv.slice(2));
  if (!source || !existsSync(source)) throw new Error('RESTORE_SOURCE_REQUIRED');
  const provider = String(env.DATABASE_PROVIDER || 'sqlite').toLowerCase();
  if (provider === 'postgres') {
    if (!String(env.DATABASE_URL || '').trim()) throw new Error('DATABASE_URL_REQUIRED');
    (options.execFileImpl || execFileSync)(env.PG_RESTORE_BIN || 'pg_restore', ['--clean', '--if-exists', '--no-owner', '--no-privileges', `--dbname=${env.DATABASE_URL}`, source], { stdio: 'inherit' });
  } else {
    const target = options.databasePath || databasePath(env); mkdirSync(dirname(target), { recursive: true }); copyFileSync(source, target);
  }
  return { ok: true, provider };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  try { console.log(JSON.stringify({ event: 'database.restore_completed', ...await restoreDatabase() })); }
  catch { console.error(JSON.stringify({ event: 'database.restore_failed' })); process.exitCode = 1; }
}
