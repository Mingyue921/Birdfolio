import { existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';

function safeKey(key) {
  const value = String(key || '').replaceAll('\\', '/');
  if (!value || value.startsWith('/') || value.includes('../') || basename(value) !== value) throw new Error('INVALID_MEDIA_KEY');
  return value;
}

export function createLocalMediaStorage(dataDir) {
  const root = join(dataDir, 'uploads'); mkdirSync(root, { recursive: true });
  return {
    kind: 'local',
    async putObject(key, buffer) { key = safeKey(key); const path = join(root, key); mkdirSync(dirname(path), { recursive: true }); writeFileSync(path, buffer, { flag: 'wx' }); return { key, locator: path }; },
    async getObject(key) { const path = join(root, safeKey(key)); return existsSync(path) ? readFileSync(path) : null; },
    async deleteObject(key) { const path = join(root, safeKey(key)); if (!existsSync(path)) return true; try { unlinkSync(path); return true; } catch { return false; } },
    async health() { return true; }
  };
}

export async function createObsMediaStorage(env, options = {}) {
  const module = options.obsModule || await import('esdk-obs-nodejs');
  const ObsClient = module.default || module.ObsClient || module;
  const bucket = String(env.OBS_BUCKET || '').trim();
  if (!bucket) throw new Error('OBS_BUCKET_REQUIRED');
  const client = options.client || new ObsClient({ access_key_id: env.OBS_ACCESS_KEY_ID, secret_access_key: env.OBS_SECRET_ACCESS_KEY, server: env.OBS_ENDPOINT, security_token: env.OBS_SECURITY_TOKEN || undefined });
  const call = (method, input) => new Promise((resolve, reject) => client[method](input, (error, result) => error ? reject(error) : Number(result?.CommonMsg?.Status || 500) >= 300 ? reject(new Error(`OBS_${result.CommonMsg.Status}`)) : resolve(result)));
  return {
    kind: 'obs',
    async putObject(key, buffer, contentType) { key = safeKey(key); await call('putObject', { Bucket: bucket, Key: key, Body: buffer, ContentType: contentType }); return { key, locator: `obs://${bucket}/${key}` }; },
    async getObject(key) { key = safeKey(key); const result = await call('getObject', { Bucket: bucket, Key: key, SaveAsBuffer: true }); return result.InterfaceResult.Content; },
    async deleteObject(key) { key = safeKey(key); await call('deleteObject', { Bucket: bucket, Key: key }); return true; },
    async health() { await call('getBucketMetadata', { Bucket: bucket }); return true; },
    close() { client.close?.(); }
  };
}

export async function createMediaStorage(env, dataDir, options = {}) {
  return String(env.MEDIA_STORAGE || 'local').toLowerCase() === 'obs' ? createObsMediaStorage(env, options) : createLocalMediaStorage(dataDir);
}
