import { BirdSpecies, Observation, ObservationInput, MonthlyObservationStat, SpeciesObservationStat, PlaceObservationStat, YearStats } from '../models/BirdModels';

export class ObservationService {
  static speciesName(species: BirdSpecies[], speciesId: string): string {
    const matched = species.find((item: BirdSpecies) => item.id === speciesId);
    return matched ? matched.name : '未选择鸟种';
  }

  static findById(observations: Observation[], selectedRecordId: string): Observation | undefined {
    return observations.find((item: Observation) => item.id === selectedRecordId);
  }

  static selectedObservation(observations: Observation[], selectedRecordId: string): Observation {
    const matched = ObservationService.findById(observations, selectedRecordId);
    return matched ? matched : observations[0];
  }

  static speciesCount(observations: Observation[]): number {
    const ids: string[] = [];
    observations.forEach((item: Observation) => {
      if (ids.indexOf(item.speciesId) < 0) {
        ids.push(item.speciesId);
      }
    });
    return ids.length;
  }

  static placeCount(observations: Observation[]): number {
    const places: string[] = [];
    observations.forEach((item: Observation) => {
      if (places.indexOf(item.placeName) < 0) {
        places.push(item.placeName);
      }
    });
    return places.length;
  }

  static totalBirdCount(observations: Observation[]): number {
    let total = 0;
    observations.forEach((item: Observation) => {
      total += item.count;
    });
    return total;
  }

  static speciesFrequency(observations: Observation[], speciesId: string): number {
    return observations.filter((item: Observation) => item.speciesId === speciesId).length;
  }

  static photoRecordCount(observations: Observation[]): number {
    return observations.filter((item: Observation) => item.photos.length > 0).length;
  }

  static yearOf(observation: Observation): number {
    const match = /^([0-9]{4})/.exec(observation.observedAt || '');
    return match ? Number(match[1]) : 0;
  }

  static years(observations: Observation[]): number[] {
    const values: number[] = [new Date().getFullYear()];
    observations.forEach((item: Observation) => {
      const year = ObservationService.yearOf(item);
      if (year > 0 && values.indexOf(year) < 0) values.push(year);
    });
    return values.sort((a: number, b: number) => b - a);
  }

  static observationsForYear(observations: Observation[], year: number): Observation[] {
    return observations.filter((item: Observation) => ObservationService.yearOf(item) === year);
  }

  static monthlyStats(observations: Observation[]): MonthlyObservationStat[] {
    const result: MonthlyObservationStat[] = [];
    for (let month = 1; month <= 12; month++) result.push({ month: month, count: 0 });
    observations.forEach((item: Observation) => {
      const match = /^[0-9]{4}-([0-9]{2})/.exec(item.observedAt || '');
      if (match) { const month = Number(match[1]); if (month >= 1 && month <= 12) result[month - 1].count += 1; }
    });
    return result;
  }

  static speciesStats(observations: Observation[]): SpeciesObservationStat[] {
    const result: SpeciesObservationStat[] = [];
    observations.forEach((item: Observation) => {
      const found = result.find((entry: SpeciesObservationStat) => entry.speciesId === item.speciesId);
      if (found) found.count += 1;
      else result.push({ speciesId: item.speciesId, count: 1, ratio: 0 });
    });
    const total = observations.length;
    result.forEach((item: SpeciesObservationStat) => item.ratio = total > 0 ? item.count / total : 0);
    return result.sort((a: SpeciesObservationStat, b: SpeciesObservationStat) => b.count - a.count);
  }

  static placeStats(observations: Observation[]): PlaceObservationStat[] {
    const grouped: PlaceObservationStat[] = [];
    observations.forEach((item: Observation) => {
      const key = item.placeName || '未命名地点';
      let place = grouped.find((entry: PlaceObservationStat) => entry.placeName === key);
      if (!place) { place = { placeName: key, recordCount: 0, birdCount: 0, latitude: 0, longitude: 0 }; grouped.push(place); }
      place.recordCount += 1; place.birdCount += item.count; place.latitude += item.latitude; place.longitude += item.longitude;
    });
    grouped.forEach((place: PlaceObservationStat) => { place.latitude /= place.recordCount; place.longitude /= place.recordCount; });
    return grouped.sort((a: PlaceObservationStat, b: PlaceObservationStat) => b.recordCount - a.recordCount);
  }

  static validPlaces(observations: Observation[]): PlaceObservationStat[] {
    return ObservationService.placeStats(observations).filter((item: PlaceObservationStat) => Number.isFinite(item.latitude) && Number.isFinite(item.longitude) && item.latitude >= -90 && item.latitude <= 90 && item.longitude >= -180 && item.longitude <= 180 && (item.latitude !== 0 || item.longitude !== 0));
  }

  static yearStats(observations: Observation[], year: number): YearStats {
    const selected = ObservationService.observationsForYear(observations, year);
    return { year: year, observations: selected.length, speciesCount: ObservationService.speciesCount(selected), birdCount: ObservationService.totalBirdCount(selected), photoRecords: ObservationService.photoRecordCount(selected), placeCount: ObservationService.placeCount(selected), monthly: ObservationService.monthlyStats(selected), species: ObservationService.speciesStats(selected), places: ObservationService.placeStats(selected) };
  }

  static filterSpecies(species: BirdSpecies[], keyword: string): BirdSpecies[] {
    const normalized = keyword.trim().toLowerCase();
    if (normalized.length === 0) {
      return species;
    }
    return species.filter((item: BirdSpecies) => {
      const haystack = item.name + item.scientificName + item.aliases.join('') + item.category + item.regions.join('');
      return haystack.toLowerCase().indexOf(normalized) >= 0;
    });
  }

  static createObservation(input: ObservationInput): Observation {
    const count = Number(input.countText);
    const safeCount = count > 0 ? count : 1;
    const placeName = input.placeName.trim().length > 0 ? input.placeName.trim() : '未命名地点';
    const now = new Date().getTime().toString();
    const hasCoordinates = ObservationService.validCoordinates(input.latitude, input.longitude);
    const latitude = hasCoordinates ? input.latitude as number : 0;
    const longitude = hasCoordinates ? input.longitude as number : 0;
    return {
      id: 'obs-' + (input.existingCount + 1).toString() + '-' + now,
      userId: 'demo-user',
      speciesId: input.speciesId,
      count: safeCount,
      observedAt: input.observedAt && input.observedAt.length > 0 ? input.observedAt : ObservationService.todayText(),
      latitude: latitude,
      longitude: longitude,
      placeName: placeName,
      photos: input.photos,
      audioNote: input.audioNote,
      note: input.note,
      fuzzyLocation: input.fuzzyLocation,
      createdAt: '刚刚',
      behaviors: input.behaviors ? input.behaviors : [],
      updatedAt: now,
      locationSource: hasCoordinates ? (input.locationSource || 'current') : 'none'
    };
  }

  static updateObservation(observations: Observation[], id: string, input: ObservationInput): Observation[] {
    const current = ObservationService.findById(observations, id);
    if (!current) return observations;
    const count = Number(input.countText);
    const preserveCoordinates = input.latitude === undefined && input.longitude === undefined;
    const hasInputCoordinates = ObservationService.validCoordinates(input.latitude, input.longitude);
    const latitude = preserveCoordinates ? current.latitude : (hasInputCoordinates ? input.latitude as number : 0);
    const longitude = preserveCoordinates ? current.longitude : (hasInputCoordinates ? input.longitude as number : 0);
    const updated: Observation = {
      id: current.id,
      userId: current.userId,
      speciesId: input.speciesId,
      count: count > 0 ? count : 1,
      observedAt: input.observedAt && input.observedAt.length > 0 ? input.observedAt : current.observedAt,
      latitude: latitude as number,
      longitude: longitude as number,
      placeName: input.placeName.trim().length > 0 ? input.placeName.trim() : '未命名地点',
      photos: input.photos,
      audioNote: input.audioNote,
      note: input.note,
      fuzzyLocation: input.fuzzyLocation,
      createdAt: current.createdAt,
      behaviors: input.behaviors ? input.behaviors : [],
      updatedAt: new Date().getTime().toString(),
      locationSource: (latitude !== 0 || longitude !== 0) ? (input.locationSource || current.locationSource || 'current') : 'none'
    };
    return observations.map((item: Observation) => item.id === id ? updated : item);
  }

  static deleteObservation(observations: Observation[], id: string): Observation[] {
    return observations.filter((item: Observation) => item.id !== id);
  }

  static normalizeObservation(record: Observation): Observation {
    const hasCoordinates = ObservationService.validCoordinates(record.latitude, record.longitude);
    return {
      id: record.id,
      userId: record.userId || 'demo-user',
      speciesId: record.speciesId || 'egret',
      count: record.count > 0 ? record.count : 1,
      observedAt: record.observedAt || ObservationService.todayText(),
      latitude: hasCoordinates ? record.latitude : 0,
      longitude: hasCoordinates ? record.longitude : 0,
      placeName: record.placeName && record.placeName.trim().length > 0 ? record.placeName : '未命名地点',
      photos: record.photos ? record.photos : [],
      audioNote: record.audioNote || '',
      note: record.note || '',
      fuzzyLocation: record.fuzzyLocation !== false,
      createdAt: record.createdAt || record.observedAt || '未知时间',
      behaviors: record.behaviors ? record.behaviors : [],
      updatedAt: record.updatedAt ? record.updatedAt : record.createdAt,
      locationSource: hasCoordinates ? (record.locationSource || 'current') : 'none'
    };
  }

  private static validLatitude(value: number | undefined): boolean {
    return value !== undefined && Number.isFinite(value) && value >= -90 && value <= 90;
  }

  private static validLongitude(value: number | undefined): boolean {
    return value !== undefined && Number.isFinite(value) && value >= -180 && value <= 180;
  }

  private static validCoordinates(latitude: number | undefined, longitude: number | undefined): boolean {
    return ObservationService.validLatitude(latitude) && ObservationService.validLongitude(longitude) && (latitude !== 0 || longitude !== 0);
  }

  static parseStoredObservations(raw: string, fallback: Observation[]): Observation[] {
    if (raw.length === 0) return fallback;
    try {
      const parsed = JSON.parse(raw) as Observation[];
      if (!Array.isArray(parsed)) return fallback;
      const valid = parsed.filter((item: Observation) => item && typeof item.id === 'string' && typeof item.speciesId === 'string');
      return valid.map((item: Observation) => ObservationService.normalizeObservation(item));
    } catch (error) {
      return fallback;
    }
  }

  private static todayText(): string {
    const date = new Date();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return date.getFullYear().toString() + '-' + month + '-' + day;
  }
}
