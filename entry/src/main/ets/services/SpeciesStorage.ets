import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BirdSpecies } from '../models/BirdModels';

const STORE_NAME = 'birdfolio_species';
const CUSTOM_SPECIES_KEY = 'custom_species';

export class SpeciesStorage {
  static async load(context: common.UIAbilityContext): Promise<BirdSpecies[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(CUSTOM_SPECIES_KEY, '');
      if (typeof raw !== 'string' || raw.length === 0) return [];
      const parsed = JSON.parse(raw) as BirdSpecies[];
      return Array.isArray(parsed) ? parsed.filter((item: BirdSpecies) => item && item.id.startsWith('ai-') && item.name.length > 0) : [];
    } catch (_error) { return []; }
  }

  static async save(context: common.UIAbilityContext, items: BirdSpecies[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(CUSTOM_SPECIES_KEY, JSON.stringify(items));
      await store.flush();
      return true;
    } catch (_error) { return false; }
  }
}
