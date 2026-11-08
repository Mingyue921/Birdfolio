import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Observation } from '../models/BirdModels';
import { ObservationService } from './ObservationService';

const STORE_NAME = 'birdfolio_store';
const OBSERVATIONS_KEY = 'observations';

export class ObservationStorage {
  static async load(context: common.UIAbilityContext, fallback: Observation[]): Promise<Observation[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(OBSERVATIONS_KEY, '');
      if (typeof raw === 'string' && raw.length > 0) {
        return ObservationService.parseStoredObservations(raw, fallback);
      }
    } catch (error) {
      return fallback;
    }
    return fallback;
  }

  static async save(context: common.UIAbilityContext, observations: Observation[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(OBSERVATIONS_KEY, JSON.stringify(observations));
      await store.flush();
      return true;
    } catch (error) {
      return false;
    }
  }
}
