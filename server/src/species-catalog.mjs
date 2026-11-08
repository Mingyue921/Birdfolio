import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
export const speciesCatalog = JSON.parse(readFileSync(join(here, '..', '..', 'catalog', 'birds.zh-CN.json'), 'utf8'));

function key(value) {
  return String(value || '').trim().toLocaleLowerCase('en-US');
}

export function findCatalogSpecies(candidate) {
  const scientificName = key(candidate?.scientificName);
  const name = key(candidate?.name);
  return speciesCatalog.find(item => key(item.scientificName) === scientificName || key(item.name) === name || item.aliases.some(alias => key(alias) === name));
}
