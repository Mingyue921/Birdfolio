import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { get as httpsGet } from 'node:https';
import { dirname } from 'node:path';

const GBIF_API = 'https://api.gbif.org/v1';
const AVES_KEY = '212';
const CACHE_TTL_MS = 30 * 60 * 1000;
const cache = new Map();

function readPersistentCache(path, cacheKey) {
  if (!path || !existsSync(path)) return null;
  try {
    const payload = JSON.parse(readFileSync(path, 'utf8'));
    return payload?.[cacheKey] || null;
  } catch {
    return null;
  }
}

function writePersistentCache(path, cacheKey, value) {
  if (!path) return;
  try {
    mkdirSync(dirname(path), { recursive: true });
    let payload = {};
    if (existsSync(path)) payload = JSON.parse(readFileSync(path, 'utf8'));
    payload[cacheKey] = { createdAt: Date.now(), value };
    writeFileSync(path, JSON.stringify(payload), 'utf8');
  } catch {
    // A cache write failure must not break the catalogue response.
  }
}

const localNames = new Map([
  ['Egretta garzetta', { id: 'egret', name: '白鹭' }],
  ['Alcedo atthis', { id: 'kingfisher', name: '普通翠鸟' }],
  ['Pica serica', { id: 'magpie', name: '喜鹊' }],
  ['Pycnonotus sinensis', { id: 'bulbul', name: '白头鹎' }],
  ['Passer montanus', { id: 'sparrow', name: '树麻雀' }],
  ['Hirundo rustica', { id: 'swallow', name: '家燕' }]
]);

function licenseInfo(value) {
  const license = String(value || '').toLowerCase();
  if (license.includes('publicdomain/zero/1.0') || license.includes('creativecommons.org/publicdomain/zero/1.0')) {
    return { label: 'CC0 1.0', commercial: true };
  }
  if (license.includes('creativecommons.org/licenses/by/4.0')) {
    return { label: 'CC BY 4.0', commercial: true };
  }
  return { label: '', commercial: false };
}

function commercialImage(media = []) {
  for (const item of Array.isArray(media) ? media : []) {
    const license = licenseInfo(item?.license);
    const identifier = String(item?.identifier || '');
    if (license.commercial && /^https?:\/\//i.test(identifier)) {
      return {
        imageUrl: identifier,
        imageCreator: String(item?.creator || 'GBIF 数据贡献者'),
        imageLicense: license.label,
        imageSourceUrl: String(item?.references || '')
      };
    }
  }
  return { imageUrl: '', imageCreator: '', imageLicense: '', imageSourceUrl: '' };
}

function birdItem(source, media = source?.media) {
  const key = Number(source?.speciesKey || source?.key || source?.usageKey || 0);
  const scientificName = String(source?.species || source?.canonicalName || source?.scientificName || '').trim();
  if (!key || !scientificName) return null;
  const local = localNames.get(scientificName);
  const image = commercialImage(media);
  const region = String(source?.stateProvince || source?.country || 'GBIF 全球记录');
  return {
    id: local?.id || `gbif-${key}`,
    gbifKey: key,
    name: local?.name || String(source?.vernacularName || scientificName),
    scientificName,
    aliases: [],
    category: String(source?.family || 'Aves'),
    description: '来自 GBIF 的开放物种与出现记录；分类、地点和媒体授权以来源页为准。',
    regions: [region],
    imageHint: '',
    ...image,
    sourceUrl: `https://www.gbif.org/species/${key}`,
    dataSource: 'GBIF'
  };
}

async function gbifJson(path, fetchImpl) {
  const url = `${GBIF_API}${path}`;
  const headers = { accept: 'application/json', 'user-agent': 'Birdfolio/1.0 (GBIF species catalogue)' };
  if (fetchImpl !== fetch) {
    const response = await fetchImpl(url, { headers, signal: AbortSignal.timeout(30000) });
    if (!response.ok) throw new Error(`GBIF_${response.status}`);
    return response.json();
  }
  return new Promise((resolve, reject) => {
    const request = httpsGet(url, { headers, family: 4 }, response => {
      const chunks = [];
      response.on('data', chunk => chunks.push(chunk));
      response.on('end', () => {
        if (!response.statusCode || response.statusCode < 200 || response.statusCode >= 300) {
          reject(new Error(`GBIF_${response.statusCode || 0}`));
          return;
        }
        try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); }
        catch { reject(new Error('GBIF_INVALID_JSON')); }
      });
    });
    request.setTimeout(30000, () => request.destroy(new Error('GBIF_TIMEOUT')));
    request.on('error', reject);
  });
}

async function browseBirds(limit, fetchImpl) {
  const params = new URLSearchParams({
    taxon_key: AVES_KEY,
    country: 'CN',
    media_type: 'StillImage',
    limit: String(Math.min(100, Math.max(24, limit * 2)))
  });
  params.append('license', 'CC_BY_4_0');
  params.append('license', 'CC0_1_0');
  const payload = await gbifJson(`/occurrence/search?${params}`, fetchImpl);
  const seen = new Set();
  const items = [];
  for (const occurrence of payload.results || []) {
    const item = birdItem(occurrence);
    if (!item || seen.has(item.id)) continue;
    seen.add(item.id);
    items.push(item);
    if (items.length >= limit) break;
  }
  return items;
}

async function searchBirds(query, limit, fetchImpl) {
  const params = new URLSearchParams({
    q: query,
    highertaxon_key: AVES_KEY,
    rank: 'SPECIES',
    status: 'ACCEPTED',
    limit: String(limit)
  });
  const payload = await gbifJson(`/species/search?${params}`, fetchImpl);
  const candidates = (payload.results || []).filter(item => item?.class === 'Aves').slice(0, limit);
  return Promise.all(candidates.map(async candidate => {
    const key = Number(candidate.key || 0);
    let media = [];
    if (key) {
      const occurrenceParams = new URLSearchParams({ taxon_key: String(key), media_type: 'StillImage', limit: '8' });
      occurrenceParams.append('license', 'CC_BY_4_0');
      occurrenceParams.append('license', 'CC0_1_0');
      const occurrence = await gbifJson(`/occurrence/search?${occurrenceParams}`, fetchImpl).catch(() => ({ results: [] }));
      media = (occurrence.results || []).flatMap(item => item.media || []);
    }
    return birdItem(candidate, media);
  })).then(items => items.filter(Boolean));
}

export async function searchGbifBirds(options = {}) {
  const query = String(options.query || '').trim().slice(0, 80);
  const limit = Math.min(30, Math.max(6, Number(options.limit) || 20));
  const fetchImpl = options.fetchImpl || fetch;
  const cachePath = options.cachePath || '';
  const cacheKey = `${query.toLowerCase()}|${limit}`;
  const cached = cache.get(cacheKey) || readPersistentCache(cachePath, cacheKey);
  if (cached && Date.now() - cached.createdAt < CACHE_TTL_MS) return cached.value;

  try {
    const items = query ? await searchBirds(query, limit, fetchImpl) : await browseBirds(limit, fetchImpl);
    const value = {
      source: 'GBIF',
      query,
      items,
      notice: '物种信息来自 GBIF；仅展示 CC0 1.0 或 CC BY 4.0 图片，并保留作者、许可和来源链接。'
    };
    const entry = { createdAt: Date.now(), value };
    cache.set(cacheKey, entry);
    writePersistentCache(cachePath, cacheKey, value);
    return value;
  } catch (error) {
    if (cached?.value) {
      return { ...cached.value, source: 'GBIF_CACHE', notice: 'GBIF 当前连接失败，正在展示最近一次成功缓存的数据。' };
    }
    return {
      source: 'GBIF_UNAVAILABLE',
      query,
      items: [],
      notice: `GBIF 当前连接失败，已使用离线图鉴（${String(error?.message || 'network error')}）。`
    };
  }
}

export { birdItem, commercialImage };
