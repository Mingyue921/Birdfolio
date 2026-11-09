const DEFAULT_SENSITIVE_SPECIES = ['nest', 'raptor-nest', 'rare-breeding'];

function finite(value) { const number = Number(value); return Number.isFinite(number) ? number : undefined; }
function coarse(value, decimals = 2) { return Math.round(value * (10 ** decimals)) / (10 ** decimals); }

export function protectObservationLocation(input, env = {}) {
  if (!input || typeof input !== 'object') return input;
  const result = { ...input };
  const latitude = finite(result.latitude); const longitude = finite(result.longitude);
  if (latitude === undefined || longitude === undefined) return result;
  const sensitive = new Set(String(env.SENSITIVE_SPECIES_IDS || DEFAULT_SENSITIVE_SPECIES.join(',')).split(',').map(value => value.trim()).filter(Boolean));
  const shouldBlur = result.fuzzyLocation === true || sensitive.has(String(result.speciesId || ''));
  if (shouldBlur) {
    result.latitude = coarse(latitude); result.longitude = coarse(longitude);
    result.locationPrecision = 'coarse'; result.fuzzyLocation = true;
  } else result.locationPrecision = 'exact';
  return result;
}

export function protectCommunityLocation(input) {
  if (!input || typeof input !== 'object') return input;
  const result = { ...input };
  delete result.latitude; delete result.longitude; delete result.coordinates; delete result.exactLocation;
  result.locationPrecision = 'place-name';
  return result;
}
