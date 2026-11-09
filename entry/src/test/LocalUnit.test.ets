import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { INITIAL_OBSERVATIONS, SPECIES } from '../main/ets/data/BirdSeedData';
import { ObservationService } from '../main/ets/services/ObservationService';
import { SyncQueueService } from '../main/ets/services/SyncQueueService';
import { JournalService } from '../main/ets/services/JournalService';
import { Observation } from '../main/ets/models/BirdModels';
import { PersistencePolicy } from '../main/ets/persistence/PersistencePolicy';
import { MediaAssetService } from '../main/ets/media/MediaAssetService';
import { AuthSession, PrivacySettings } from '../main/ets/models/BetaModels';
import { AuthSessionPolicy } from '../main/ets/services/AuthSessionPolicy';
import { PrivacyPolicy, PRIVACY_POLICY_VERSION } from '../main/ets/services/PrivacyPolicy';
import { ReleaseLogPolicy } from '../main/ets/services/ReleaseLogPolicy';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });
    it('calculateObservationStats', 0, () => {
      expect(ObservationService.speciesCount(INITIAL_OBSERVATIONS)).assertEqual(3);
      expect(ObservationService.placeCount(INITIAL_OBSERVATIONS)).assertEqual(3);
      expect(ObservationService.totalBirdCount(INITIAL_OBSERVATIONS)).assertEqual(7);
      expect(ObservationService.photoRecordCount(INITIAL_OBSERVATIONS)).assertEqual(1);
    });
    it('filterSpeciesByAliasAndScientificName', 0, () => {
      expect(ObservationService.filterSpecies(SPECIES, '白头翁').length).assertEqual(1);
      expect(ObservationService.filterSpecies(SPECIES, 'Alcedo').length).assertEqual(1);
    });
    it('createObservationWithSafeDefaults', 0, () => {
      const observation = ObservationService.createObservation({
        speciesId: 'egret',
        countText: '0',
        placeName: '',
        audioNote: '',
        note: 'test note',
        fuzzyLocation: true,
        photos: [],
        latitude: 39,
        longitude: 116,
        existingCount: 3
      });
      expect(observation.count).assertEqual(1);
      expect(observation.placeName).assertEqual('未命名地点');
      expect(observation.fuzzyLocation).assertTrue();
      expect(observation.behaviors?.length).assertEqual(0);
      expect(observation.latitude).assertEqual(39);
      expect(observation.longitude).assertEqual(116);
      expect(observation.locationSource).assertEqual('current');
    });
    it('findUpdateAndDeleteObservation', 0, () => {
      const source = INITIAL_OBSERVATIONS;
      const target = ObservationService.findById(source, 'obs-1');
      expect(target !== undefined).assertTrue();
      const updated = ObservationService.updateObservation(source, 'obs-1', {
        speciesId: 'kingfisher', countText: '3', observedAt: '2026-06-08', placeName: '新地点',
        audioNote: '', note: '已编辑', fuzzyLocation: false, photos: [], behaviors: ['鸣叫'],
        existingCount: source.length
      });
      const changed = ObservationService.findById(updated, 'obs-1');
      expect(changed?.speciesId).assertEqual('kingfisher');
      expect(changed?.count).assertEqual(3);
      expect(changed?.createdAt).assertEqual(target?.createdAt);
      expect(changed?.latitude).assertEqual(target?.latitude);
      expect(ObservationService.deleteObservation(updated, 'obs-1').length).assertEqual(2);
      expect(ObservationService.deleteObservation(updated, 'missing').length).assertEqual(3);
    });
    it('doesNotChangeRecordsWhenUpdatingMissingId', 0, () => {
      const source = INITIAL_OBSERVATIONS;
      const updated = ObservationService.updateObservation(source, 'missing', {
        speciesId: 'kingfisher', countText: '9', observedAt: '2026-06-08', placeName: '不应保存',
        audioNote: '', note: '不应修改', fuzzyLocation: false, photos: [], behaviors: ['鸣叫'],
        existingCount: source.length
      });
      expect(updated.length).assertEqual(source.length);
      expect(updated[0].id).assertEqual(source[0].id);
      expect(updated[0].speciesId).assertEqual(source[0].speciesId);
      expect(updated[0].count).assertEqual(source[0].count);
    });
    it('keepsExistingObservationDateWhenEditingWithoutDate', 0, () => {
      const source = INITIAL_OBSERVATIONS;
      const original = ObservationService.findById(source, 'obs-1');
      const updated = ObservationService.updateObservation(source, 'obs-1', {
        speciesId: original?.speciesId || 'egret', countText: '2', observedAt: '', placeName: original?.placeName || '',
        audioNote: original?.audioNote || '', note: '修改笔记', fuzzyLocation: original?.fuzzyLocation !== false,
        photos: original?.photos || [], behaviors: ['觅食'], existingCount: source.length
      });
      const changed = ObservationService.findById(updated, 'obs-1');
      expect(changed?.observedAt).assertEqual(original?.observedAt);
      expect(changed?.createdAt).assertEqual(original?.createdAt);
      expect(changed?.note).assertEqual('修改笔记');
      expect(changed?.updatedAt !== original?.updatedAt).assertTrue();
    });
    it('normalizeLegacyObservation', 0, () => {
      const legacy = { id: 'legacy', userId: '', speciesId: 'egret', count: 0, observedAt: '', latitude: 0, longitude: 0,
        placeName: '', photos: [], audioNote: '', note: '', fuzzyLocation: true, createdAt: '旧记录' } as Observation;
      const normalized = ObservationService.normalizeObservation(legacy);
      expect(normalized.count).assertEqual(1);
      expect(normalized.placeName).assertEqual('未命名地点');
      expect(normalized.behaviors?.length).assertEqual(0);
      expect(normalized.locationSource).assertEqual('none');
      expect(ObservationService.parseStoredObservations('broken', [legacy]).length).assertEqual(1);
    });
    it('rejectsIncompleteCoordinatesAndReplacesCoordinatesOnEdit', 0, () => {
      const withoutCoordinates = ObservationService.createObservation({
        speciesId: 'egret', countText: '1', placeName: '手动地点', audioNote: '', note: '', fuzzyLocation: true,
        photos: [], latitude: 39, existingCount: 0
      });
      expect(withoutCoordinates.latitude).assertEqual(0);
      expect(withoutCoordinates.longitude).assertEqual(0);
      expect(withoutCoordinates.locationSource).assertEqual('none');
      const updated = ObservationService.updateObservation(INITIAL_OBSERVATIONS, 'obs-1', {
        speciesId: 'egret', countText: '1', placeName: '新地点', audioNote: '', note: '', fuzzyLocation: true,
        photos: [], latitude: 31.2, longitude: 121.5, locationSource: 'current', existingCount: 3
      });
      const changed = ObservationService.findById(updated, 'obs-1');
      expect(changed?.latitude).assertEqual(31.2);
      expect(changed?.longitude).assertEqual(121.5);
    });
    it('aggregatesYearMonthSpeciesAndPlaces', 0, () => {
      const stats = ObservationService.yearStats(INITIAL_OBSERVATIONS, 2026);
      expect(stats.observations).assertEqual(3);
      expect(stats.monthly.length).assertEqual(12);
      expect(stats.species.length).assertEqual(3);
      expect(stats.places.length).assertEqual(3);
      expect(stats.monthly[5].count).assertEqual(3);
      expect(stats.species[0].count).assertEqual(1);
      expect(stats.places[0].recordCount).assertEqual(1);
    });
    it('handlesEmptyStatsAndInvalidCoordinates', 0, () => {
      const stats = ObservationService.yearStats([], 2026);
      expect(stats.observations).assertEqual(0);
      expect(stats.monthly.length).assertEqual(12);
      expect(stats.species.length).assertEqual(0);
      const invalid = ObservationService.normalizeObservation(INITIAL_OBSERVATIONS[0]);
      invalid.latitude = 0;
      invalid.longitude = 0;
      expect(ObservationService.validPlaces([invalid]).length).assertEqual(0);
    });
    it('returnsCurrentAndHistoricalYears', 0, () => {
      const historical = ObservationService.normalizeObservation(INITIAL_OBSERVATIONS[0]);
      historical.observedAt = '2024-01-02';
      const years = ObservationService.years([historical]);
      expect(years.indexOf(2024) >= 0).assertTrue();
      expect(years.indexOf(new Date().getFullYear()) >= 0).assertTrue();
    });
    it('manageSyncQueue', 0, () => {
      const job = SyncQueueService.createJob('createObservation', 'obs-test', '{}');
      expect(SyncQueueService.pendingCount([job])).assertEqual(1);
      const synced = SyncQueueService.markPendingAsSynced([job]);
      expect(SyncQueueService.pendingCount(synced)).assertEqual(0);
      expect(SyncQueueService.compactSynced(synced).length).assertEqual(0);
    });
    it('createsAndEditsJournalBook', 0, () => {
      const book = JournalService.createBook(INITIAL_OBSERVATIONS.slice(0, 2), SPECIES);
      expect(book.pages.length).assertEqual(2);
      expect(book.observationIds.length).assertEqual(2);
      const withPage = JournalService.addPage(book);
      expect(withPage.pages.length).assertEqual(3);
      const minimal = JournalService.applyTemplate(withPage, 'minimal');
      expect(minimal.templateId).assertEqual('minimal');
      expect(minimal.pages[0].elements.length).assertEqual(book.pages[0].elements.length);
    });
    it('clampsJournalElementTransformsAndDrawings', 0, () => {
      const book = JournalService.createBook([], SPECIES);
      const element = JournalService.element('text-test', 'text', 10, 10, 100, 40, 'test', 1);
      const added = JournalService.addElement(book, 0, element);
      const transformed = JournalService.transformElement(added, 0, 'text-test', 900, -100, 9, -15);
      expect(transformed.pages[0].elements[0].x).assertEqual(696);
      expect(transformed.pages[0].elements[0].y).assertEqual(-90);
      expect(transformed.pages[0].elements[0].scale).assertEqual(3);
      expect(transformed.pages[0].elements[0].rotation).assertEqual(345);
      const drawing = JournalService.element('draw-test', 'drawing', 1, 1, 10, 10, 'stroke', 2);
      const withDrawing = JournalService.addElement(transformed, 0, drawing);
      expect(JournalService.undoLastDrawing(withDrawing, 0).pages[0].elements.length).assertEqual(1);
    });
    it('parsesBrokenJournalStorageSafely', 0, () => {
      expect(JournalService.parse('broken').length).assertEqual(0);
      expect(JournalService.parse('[]').length).assertEqual(0);
    });
    it('migratesLegacyJournalElementsToVersionThree', 0, () => {
      const legacy = JournalService.createBook(INITIAL_OBSERVATIONS.slice(0, 1), SPECIES);
      legacy.editorVersion = 2;
      legacy.pages[0].elements[0].visible = undefined;
      legacy.pages[0].elements[0].role = undefined;
      const migrated = JournalService.parse(JSON.stringify([legacy]))[0];
      expect(migrated.editorVersion).assertEqual(3);
      expect(migrated.pages[0].elements[0].visible).assertTrue();
      expect(migrated.pages[0].elements[0].role).assertEqual('title');
    });
    it('persistsJournalStylesAndLayerFlags', 0, () => {
      const book = JournalService.createBook([], SPECIES);
      const text = JournalService.element('styled-text', 'text', 80, 90, 300, 80, '观鸟', 8, { color: '#1c241f' });
      const added = JournalService.addElement(book, 0, text);
      const styled = JournalService.updateElementStyle(added, 0, 'styled-text', { fontFamily: 'Birdfolio LongCang', fontSize: 40, fontWeight: 'bold', fontStyle: 'italic', textAlign: 'center', lineHeight: 1.7, backgroundColor: '#ffffff' });
      const hidden = JournalService.setElementVisible(styled, 0, 'styled-text', false);
      const locked = JournalService.setElementLocked(hidden, 0, 'styled-text', true);
      const restored = JournalService.parse(JSON.stringify([locked]))[0].pages[0].elements[0];
      expect(restored.style?.fontSize).assertEqual(40);
      expect(restored.style?.fontFamily).assertEqual('Birdfolio LongCang');
      expect(restored.style?.color).assertEqual('#1c241f');
      expect(restored.style?.fontWeight).assertEqual('bold');
      expect(restored.style?.fontStyle).assertEqual('italic');
      expect(restored.style?.textAlign).assertEqual('center');
      expect(restored.style?.lineHeight).assertEqual(1.7);
      expect(restored.style?.backgroundColor).assertEqual('#ffffff');
      expect(restored.visible).assertFalse();
      expect(restored.locked).assertTrue();
      const unchanged = JournalService.transformElement(locked, 0, 'styled-text', 100, 100, 2, 20);
      expect(unchanged.pages[0].elements[0].x).assertEqual(80);
    });
    it('normalizesLayersAndReordersPages', 0, () => {
      let book = JournalService.createBook([], SPECIES);
      book = JournalService.addElement(book, 0, JournalService.element('layer-a', 'text', 20, 20, 100, 40, 'A', 10));
      book = JournalService.addElement(book, 0, JournalService.element('layer-b', 'text', 30, 30, 100, 40, 'B', 30));
      book = JournalService.moveLayer(book, 0, 'layer-a', 1);
      expect(book.pages[0].elements[0].zIndex).assertEqual(0);
      expect(book.pages[0].elements[1].zIndex).assertEqual(1);
      book = JournalService.addPage(book);
      const firstId = book.pages[0].id;
      const secondId = book.pages[1].id;
      const reordered = JournalService.reorderPage(book, 0, 1);
      expect(reordered.pages[0].id).assertEqual(secondId);
      expect(reordered.pages[1].id).assertEqual(firstId);
    });
    it('templatesOnlyMoveManagedElementsAndKeepOnePage', 0, () => {
      let book = JournalService.createBook(INITIAL_OBSERVATIONS.slice(0, 1), SPECIES);
      book = JournalService.addElement(book, 0, JournalService.element('user-note', 'text', 333, 444, 200, 60, '我的文字', 20, undefined, 'user'));
      const templated = JournalService.applyTemplate(book, 'forest');
      const user = templated.pages[0].elements.find(item => item.id === 'user-note');
      const title = templated.pages[0].elements.find(item => item.role === 'title');
      expect(user?.x).assertEqual(333);
      expect(user?.y).assertEqual(444);
      expect(title?.x).assertEqual(65);
      const emptied = JournalService.deletePage(templated, 0);
      expect(emptied.pages.length).assertEqual(1);
    });
    it('normalizesLocalMetadataAndMediaReferences', 0, () => {
      const fallback = PersistencePolicy.localMeta(undefined, 1000);
      expect(fallback.version).assertEqual(1);
      expect(fallback.updatedAt).assertEqual(1000);
      expect(fallback.syncStatus).assertEqual('local');
      const ids = PersistencePolicy.uniqueAssetIds(['asset-a', '', 'asset-a', 'asset-b']);
      expect(ids.length).assertEqual(2);
      expect(ids[0]).assertEqual('asset-a');
      expect(ids[1]).assertEqual('asset-b');
      expect(PersistencePolicy.orphanCutoff(10000, 2500)).assertEqual(7500);
    });
    it('keepsSharedMediaReferencesPerOwner', 0, () => {
      const first = ObservationService.normalizeObservation(INITIAL_OBSERVATIONS[0]);
      const second = ObservationService.normalizeObservation(INITIAL_OBSERVATIONS[1]);
      first.photoAssetIds = ['shared', 'first-only', 'shared'];
      second.photoAssetIds = ['shared'];
      const owners = MediaAssetService.observationReferences([first, second]);
      expect(owners.size).assertEqual(2);
      expect(owners.get(first.id)?.length).assertEqual(2);
      expect(owners.get(second.id)?.length).assertEqual(1);
      expect(owners.get(first.id)?.[0]).assertEqual('shared');
    });
    it('keepsOneThousandObservationRecordsStable', 0, () => {
      const observations: Observation[] = [];
      for (let index = 0; index < 1000; index++) {
        const item = ObservationService.createObservation({ speciesId: 'egret', countText: '1', placeName: '地点' + index.toString(),
          audioNote: '', note: '', fuzzyLocation: true, photos: [], existingCount: index });
        observations.push(item);
      }
      expect(observations.length).assertEqual(1000);
      expect(ObservationService.totalBirdCount(observations)).assertEqual(1000);
      expect(ObservationService.placeCount(observations)).assertEqual(1000);
    });
    it('normalizesAndParsesSecureAuthSessions', 0, () => {
      const source: AuthSession = {
        accessToken: '  access-token  ', refreshToken: 'refresh-token', expiresAt: 123456,
        userId: '  user-1  ', email: ' user@example.com ', displayName: 'Bird User'
      };
      const normalized = AuthSessionPolicy.normalize(source);
      expect(normalized?.accessToken).assertEqual('access-token');
      expect(normalized?.userId).assertEqual('user-1');
      expect(normalized?.email).assertEqual('user@example.com');
      expect(AuthSessionPolicy.parse(JSON.stringify(source))?.refreshToken).assertEqual('refresh-token');
      expect(AuthSessionPolicy.parse('broken')).assertNull();
      const missingAccess: AuthSession = {
        accessToken: ' ', refreshToken: source.refreshToken, expiresAt: source.expiresAt,
        userId: source.userId, email: source.email, displayName: source.displayName
      };
      const missingUser: AuthSession = {
        accessToken: source.accessToken, refreshToken: source.refreshToken, expiresAt: source.expiresAt,
        userId: ' ', email: source.email, displayName: source.displayName
      };
      expect(AuthSessionPolicy.normalize(missingAccess)).assertNull();
      expect(AuthSessionPolicy.normalize(missingUser)).assertNull();
    });
    it('checksAuthSessionFreshnessWithoutExposingTokens', 0, () => {
      const base: AuthSession = {
        accessToken: 'access-token', refreshToken: 'refresh-token', userId: 'user-1',
        email: 'user@example.com', displayName: '', expiresAt: Date.now() + 120000
      };
      expect(AuthSessionPolicy.accessToken(base)).assertEqual('access-token');
      expect(AuthSessionPolicy.isAccessTokenFresh(base)).assertTrue();
      const expired: AuthSession = {
        accessToken: base.accessToken, refreshToken: base.refreshToken, userId: base.userId,
        email: base.email, displayName: base.displayName, expiresAt: Date.now() - 1
      };
      expect(AuthSessionPolicy.isAccessTokenFresh(expired)).assertFalse();
      expect(AuthSessionPolicy.isAccessTokenFresh(null)).assertFalse();
    });
    it('keepsIdentificationAndCutoutConsentIndependent', 0, () => {
      const now = Date.now();
      const settings: PrivacySettings = {
        aiPhotoUploadAgreed: true,
        diagnosticsEnabled: false,
        consents: [
          { purpose: 'identification', policyVersion: PRIVACY_POLICY_VERSION, agreedAt: now, revokedAt: 0 },
          { purpose: 'cutout', policyVersion: PRIVACY_POLICY_VERSION, agreedAt: 0, revokedAt: now }
        ]
      };
      expect(PrivacyPolicy.hasActiveConsent(settings, 'identification')).assertTrue();
      expect(PrivacyPolicy.hasActiveConsent(settings, 'cutout')).assertFalse();
      expect(PrivacyPolicy.latestRecord(settings, 'cutout')?.revokedAt).assertEqual(now);
    });
    it('rejectsOutdatedOrMalformedConsentRecords', 0, () => {
      const outdated: PrivacySettings = {
        aiPhotoUploadAgreed: false,
        diagnosticsEnabled: false,
        consents: [{ purpose: 'identification', policyVersion: 'old-policy', agreedAt: 1, revokedAt: 0 }]
      };
      expect(PrivacyPolicy.hasActiveConsent(outdated, 'identification')).assertFalse();
      expect(PrivacyPolicy.parseConsents('broken').length).assertEqual(0);
      expect(PrivacyPolicy.parseConsents('[{"purpose":"unknown"}]').length).assertEqual(0);
      expect(PrivacyPolicy.parseConsents('[{"purpose":"cutout","policyVersion":"v","agreedAt":5,"revokedAt":0}]').length).assertEqual(1);
    });
    it('sanitizesReleaseLogEvents', 0, () => {
      expect(ReleaseLogPolicy.event('auth.login_success')).assertEqual('auth.login_success');
      expect(ReleaseLogPolicy.event('photo uri: file:///private/user.jpg')).assertEqual('photo_uri__file____private_user.jpg');
      expect(ReleaseLogPolicy.event('')).assertEqual('unknown');
      expect(ReleaseLogPolicy.event('x'.repeat(100)).length).assertEqual(80);
    });
  });
}
