import { existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { setDefaultResultOrder } from 'node:dns';

setDefaultResultOrder('ipv4first');
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const catalogPath = join(root, 'catalog', 'birds.zh-CN.json');
const mediaDir = join(root, 'entry', 'src', 'main', 'resources', 'base', 'media');
const tempDir = join(root, 'server', 'data', 'bird-image-downloads');
const manifestPath = join(root, 'catalog', 'bird-image-attribution.json');
const partialPath = join(root, 'catalog', 'bird-image-attribution.partial.json');
const mapPath = join(root, 'entry', 'src', 'main', 'ets', 'data', 'BirdImageMap.generated.ets');
const birds = JSON.parse(readFileSync(catalogPath, 'utf8'));
mkdirSync(mediaDir, { recursive: true }); mkdirSync(tempDir, { recursive: true });

const license = value => {
  const text = String(value || '').toLowerCase();
  if (text.includes('publicdomain/zero/1.0')) return 'CC0 1.0';
  if (text.includes('creativecommons.org/licenses/by/4.0')) return 'CC BY 4.0';
  return '';
};
const resourceName = id => `bird_${id.replace(/[^a-z0-9_]/g, '_')}`;
const plainText = value => String(value || '').replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').trim();
const deliveryUrl = value => String(value || '').replace(/\/original\.(jpe?g|png)$/i, '/large.$1');

async function json(url) {
  const response = await fetch(url, { headers: { accept: 'application/json', 'user-agent': 'Birdfolio/1.0 offline image pack' }, signal: AbortSignal.timeout(60000) });
  if (!response.ok) throw new Error(`HTTP_${response.status}`);
  return response.json();
}

async function candidatesFor(bird, country) {
  const match = await json(`https://api.gbif.org/v1/species/match?name=${encodeURIComponent(bird.scientificName)}&kingdom=Animalia`);
  const key = Number(match.usageKey || 0); if (!key) return [];
  const result = [];
  for (const licenseFilter of ['CC0_1_0', 'CC_BY_4_0']) {
    const params = new URLSearchParams({ taxon_key: String(key), media_type: 'StillImage', limit: '12', license: licenseFilter });
    if (country) params.set('country', country);
    const payload = await json(`https://api.gbif.org/v1/occurrence/search?${params}`);
    for (const occurrence of payload.results || []) {
      for (const media of occurrence.media || []) {
        const imageLicense = license(media.license);
        const creator = String(media.creator || media.rightsHolder || occurrence.recordedBy || '').trim();
        const imageUrl = deliveryUrl(media.identifier).trim();
        if (!imageLicense || !creator || !/^https:\/\//i.test(imageUrl)) continue;
        result.push({
          speciesId: bird.id, name: bird.name, scientificName: bird.scientificName, imageUrl, creator,
          license: imageLicense, licenseUrl: String(media.license || ''),
          sourceUrl: `https://www.gbif.org/occurrence/${occurrence.key}`,
          gbifSpeciesKey: key, occurrenceKey: Number(occurrence.key || 0), provider: 'GBIF'
        });
      }
    }
  }
  return result;
}

async function commonsCandidates(bird) {
  const params = new URLSearchParams({ action: 'query', generator: 'search', gsrsearch: bird.scientificName, gsrnamespace: '6', gsrlimit: '15',
    prop: 'imageinfo', iiprop: 'url|extmetadata', iiurlwidth: '1200', format: 'json', origin: '*' });
  const payload = await json(`https://commons.wikimedia.org/w/api.php?${params}`);
  const result = [];
  for (const page of Object.values(payload?.query?.pages || {})) {
    const info = page?.imageinfo?.[0]; const metadata = info?.extmetadata || {};
    const label = plainText(metadata.LicenseShortName?.value);
    const imageLicense = label === 'CC0' || label === 'CC0 1.0' ? 'CC0 1.0' : (label === 'CC BY 4.0' ? 'CC BY 4.0' : '');
    const creator = plainText(metadata.Artist?.value || metadata.Credit?.value);
    const imageUrl = String(info?.thumburl || info?.url || '');
    if (!imageLicense || !creator || !/^https:\/\//i.test(imageUrl)) continue;
    result.push({ speciesId: bird.id, name: bird.name, scientificName: bird.scientificName, imageUrl, creator, license: imageLicense,
      licenseUrl: String(metadata.LicenseUrl?.value || ''), sourceUrl: String(info?.descriptionurl || ''), gbifSpeciesKey: 0,
      occurrenceKey: 0, provider: 'WIKIMEDIA_COMMONS' });
  }
  return result;
}

async function downloadAndCompress(item, bird) {
  const source = join(tempDir, `${resourceName(bird.id)}.source`);
  const output = join(mediaDir, `${resourceName(bird.id)}.jpg`);
  rmSync(source, { force: true });
  const downloaded = spawnSync('curl.exe', ['-L', '--fail', '--silent', '--show-error', '--retry', '1', '--retry-all-errors', '-C', '-', '--connect-timeout', '8', '--max-time', '30', '-A', 'Birdfolio/1.0 offline image pack', '-o', source, item.imageUrl], { encoding: 'utf8' });
  if (downloaded.status !== 0) throw new Error(`CURL_${downloaded.stderr.trim()}`);
  const size = statSync(source).size;
  if (size < 5000 || size > 30 * 1024 * 1024) { rmSync(source, { force: true }); throw new Error(`IMAGE_SIZE_${size}`); }
  const converted = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', source, '-map_metadata', '-1', '-vf', 'scale=960:720:force_original_aspect_ratio=decrease', '-frames:v', '1', '-q:v', '4', output], { encoding: 'utf8' });
  rmSync(source, { force: true });
  if (converted.status !== 0) throw new Error(`FFMPEG_${converted.stderr.trim()}`);
  return output;
}

async function fetchBird(bird) {
  let candidates = await candidatesFor(bird, '').catch(() => []);
  candidates = candidates.concat(await commonsCandidates(bird).catch(() => []));
  const seen = new Set(); const failedHosts = new Set();
  for (const item of candidates) {
    if (seen.has(item.imageUrl)) continue; seen.add(item.imageUrl);
    const host = `${item.provider}|${new URL(item.imageUrl).hostname}`;
    if (failedHosts.has(host)) continue;
    try {
      await downloadAndCompress(item, bird);
      process.stdout.write(`OK ${bird.id} ${item.license} ${item.creator}\n`);
      return item;
    } catch (error) {
      if (String(error?.message || error).toLowerCase().includes('timeout')) failedHosts.add(host);
      process.stderr.write(`RETRY ${bird.id} ${String(error.message || error).slice(0, 120)}\n`);
    }
  }
  process.stderr.write(`MISSING ${bird.id} ${bird.scientificName}\n`); return null;
}

const manifest = existsSync(partialPath) ? JSON.parse(readFileSync(partialPath, 'utf8')) : [];
const completed = new Set(manifest.filter(item => existsSync(join(mediaDir, `${resourceName(item.speciesId)}.jpg`))).map(item => item.speciesId));
const pending = birds.filter(bird => !completed.has(bird.id));
for (let index = 0; index < pending.length; index += 4) {
  const batch = await Promise.all(pending.slice(index, index + 4).map(fetchBird));
  manifest.push(...batch.filter(Boolean));
  writeFileSync(partialPath, JSON.stringify(manifest, null, 2) + '\n');
}

const byId = new Map(manifest.map(item => [item.speciesId, item]));
const enriched = birds.map(bird => {
  const image = byId.get(bird.id); if (!image) return bird;
  return { ...bird, imageCreator: image.creator, imageLicense: image.license, imageSourceUrl: image.sourceUrl,
    sourceUrl: image.gbifSpeciesKey ? `https://www.gbif.org/species/${image.gbifSpeciesKey}` : image.sourceUrl, dataSource: `${image.provider}_OFFLINE` };
});
writeFileSync(catalogPath, JSON.stringify(enriched, null, 2) + '\n');
writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
const cases = manifest.map(item => `    case '${item.speciesId}': return $r('app.media.${resourceName(item.speciesId)}');`).join('\n');
writeFileSync(mapPath, `// Generated by scripts/fetch-bird-images.mjs.\nexport function catalogSpeciesImage(id: string): Resource | undefined {\n  switch (id) {\n${cases}\n    default: return undefined;\n  }\n}\n`);
rmSync(tempDir, { recursive: true, force: true });
if (manifest.length === birds.length) rmSync(partialPath, { force: true });
console.log(`Downloaded ${manifest.length}/${birds.length} licensed bird images.`);
if (manifest.length !== birds.length) process.exitCode = 2;
