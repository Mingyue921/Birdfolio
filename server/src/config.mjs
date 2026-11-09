import { existsSync, readFileSync } from 'node:fs';
import { isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const serverRoot = resolve(fileURLToPath(new URL('..', import.meta.url)));

export function readEnvFile(path = join(serverRoot, '.env')) {
  if (!existsSync(path)) return {};
  return Object.fromEntries(readFileSync(path, 'utf8').split(/\r?\n/)
    .filter(line => line && !line.startsWith('#')).map(line => {
      const index = line.indexOf('=');
      return index < 0 ? [line.trim(), ''] : [line.slice(0, index).trim(), line.slice(index + 1).trim()];
    }));
}

export function loadEnv(overrides = {}) {
  return { ...readEnvFile(), ...process.env, ...overrides };
}

export function databasePath(env, dataDir = join(serverRoot, 'data')) {
  const configured = String(env.DATABASE_PATH || '').trim();
  if (!configured) return join(dataDir, 'birdfolio.db');
  return isAbsolute(configured) ? configured : resolve(serverRoot, configured);
}
