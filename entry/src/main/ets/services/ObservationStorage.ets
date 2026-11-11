import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { Observation } from '../models/BirdModels';
import { ObservationService } from './ObservationService';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistedPayload } from '../models/PersistenceModels';
import { MediaAssetService } from '../media/MediaAssetService';

const STORE_NAME = 'birdfolio_store';
const OBSERVATIONS_KEY = 'observations';
// v1 could mark an empty migration complete before legacy Preferences became readable.
const OBSERVATIONS_MIGRATION_KEY = 'observations-v2';

export class ObservationStorage {
  static async load(context: common.UIAbilityContext, fallback: Observation[]): Promise<Observation[]> {
    try {
      const rows = await BirdfolioDatabase.loadPayloads(context, 'observations');
      const current = ObservationStorage.parseRows(rows);
      if (!await BirdfolioDatabase.isMigrated(context, OBSERVATIONS_MIGRATION_KEY)) {
        const legacy = await ObservationStorage.loadLegacy(context, []);
        const recovered = ObservationStorage.merge(current, legacy);
        const next = recovered.length > 0 ? recovered : fallback;
        await ObservationStorage.saveDatabase(context, next);
        return next;
      }
      return current;
    } catch (error) {
      return await ObservationStorage.loadLegacy(context, fallback);
    }
  }

  static async save(context: common.UIAbilityContext, observations: Observation[]): Promise<boolean> {
    try {
      await ObservationStorage.saveDatabase(context, observations);
      return true;
    } catch (_databaseError) {
      return await ObservationStorage.saveLegacy(context, observations);
    }
  }

  private static async saveDatabase(context: common.UIAbilityContext, observations: Observation[]): Promise<void> {
    const prepared = await MediaAssetService.prepareObservations(context, observations);
    const rows: PersistedPayload[] = prepared.map((item: Observation): PersistedPayload => ({
      id: item.id, payload: JSON.stringify(item), updatedAt: ObservationStorage.timestamp(item.updatedAt)
    }));
    const owners = MediaAssetService.observationReferences(prepared);
    await BirdfolioDatabase.replacePayloadsReferencesAndMarkMigrated(context, 'observations', rows,
      OBSERVATIONS_MIGRATION_KEY, 'observation', owners);
    prepared.forEach((saved: Observation, index: number) => {
      observations[index].photos = saved.photos;
      observations[index].photoAssetIds = saved.photoAssetIds;
    });
  }

  private static parseRows(rows: PersistedPayload[]): Observation[] {
    const observations: Observation[] = [];
    rows.forEach((row: PersistedPayload) => {
      try {
        const source = JSON.parse(row.payload) as Observation;
        const normalized = ObservationService.normalizeObservation(source);
        normalized.photoAssetIds = Array.isArray(source.photoAssetIds) ? source.photoAssetIds : [];
        normalized.localMeta = source.localMeta;
        observations.push(normalized);
      } catch (_error) {}
    });
    return observations;
  }

  private static merge(current: Observation[], legacy: Observation[]): Observation[] {
    const merged = legacy.slice();
    current.forEach((item: Observation) => {
      const index = merged.findIndex((candidate: Observation) => candidate.id === item.id);
      if (index >= 0) merged[index] = item; else merged.push(item);
    });
    return merged;
  }

  private static timestamp(value: string | undefined): number {
    const numeric = Number(value); if (Number.isFinite(numeric) && numeric > 0) return numeric;
    const parsed = Date.parse(value || ''); return Number.isFinite(parsed) ? parsed : Date.now();
  }

  private static async loadLegacy(context: common.UIAbilityContext, fallback: Observation[]): Promise<Observation[]> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      const raw = await store.get(OBSERVATIONS_KEY, '');
      return typeof raw === 'string' ? ObservationService.parseStoredObservations(raw, fallback) : fallback;
    } catch (_error) { return fallback; }
  }

  private static async saveLegacy(context: common.UIAbilityContext, observations: Observation[]): Promise<boolean> {
    try {
      const store = await preferences.getPreferences(context, { name: STORE_NAME });
      await store.put(OBSERVATIONS_KEY, JSON.stringify(observations)); await store.flush(); return true;
    } catch (_error) { return false; }
  }
}
