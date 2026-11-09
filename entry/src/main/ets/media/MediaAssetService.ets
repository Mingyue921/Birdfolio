import { common } from '@kit.AbilityKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { JournalBook, JournalElement, MediaAsset, Observation, PostDraft } from '../models/BirdModels';
import { MediaCleanupResult, MediaReference, MediaReferenceOwnerType } from '../models/PersistenceModels';
import { BirdfolioDatabase } from '../persistence/BirdfolioDatabase';
import { PersistencePolicy } from '../persistence/PersistencePolicy';

const MAX_IMPORT_BYTES = 50 * 1024 * 1024;
const MAX_IMPORT_PIXELS = 60 * 1000 * 1000;
const DEFAULT_ORPHAN_GRACE_MS = PersistencePolicy.ORPHAN_GRACE_MS;

interface ImageKind {
  mimeType: string;
  extension: string;
}

export class MediaAssetService {
  static async prepareObservations(context: common.UIAbilityContext, observations: Observation[]): Promise<Observation[]> {
    const prepared: Observation[] = [];
    for (const source of observations) {
      const item = JSON.parse(JSON.stringify(source)) as Observation;
      const ids: string[] = [];
      const uris: string[] = [];
      for (let index = 0; index < item.photos.length; index++) {
        const knownId = item.photoAssetIds && item.photoAssetIds[index] ? item.photoAssetIds[index] : '';
        const asset = knownId ? await BirdfolioDatabase.findMediaAsset(context, knownId) : await MediaAssetService.tryImport(context, item.photos[index]);
        if (asset) { ids.push(asset.id); uris.push(asset.previewUri); } else { ids.push(''); uris.push(item.photos[index]); }
      }
      item.photos = uris; item.photoAssetIds = ids; prepared.push(item);
    }
    return prepared;
  }

  static async syncObservationReferences(context: common.UIAbilityContext, observations: Observation[]): Promise<void> {
    const owners = MediaAssetService.observationReferences(observations);
    await BirdfolioDatabase.replaceMediaReferences(context, 'observation', owners);
  }

  static observationReferences(observations: Observation[]): Map<string, string[]> {
    const owners = new Map<string, string[]>();
    observations.forEach((item: Observation) => owners.set(item.id, PersistencePolicy.uniqueAssetIds(item.photoAssetIds || [])));
    return owners;
  }

  static async prepareJournals(context: common.UIAbilityContext, books: JournalBook[]): Promise<JournalBook[]> {
    const prepared: JournalBook[] = JSON.parse(JSON.stringify(books)) as JournalBook[];
    for (const book of prepared) {
      for (const page of book.pages) {
        for (const element of page.elements) {
          if (element.type !== 'image' && element.type !== 'sticker') continue;
          const current = element.assetId ? await BirdfolioDatabase.findMediaAsset(context, element.assetId) : null;
          const asset = current || await MediaAssetService.tryImport(context, element.content);
          if (asset) { element.assetId = asset.id; element.content = asset.previewUri; }
        }
      }
    }
    return prepared;
  }

  static async syncJournalReferences(context: common.UIAbilityContext, books: JournalBook[]): Promise<void> {
    const owners = MediaAssetService.journalReferences(books);
    await BirdfolioDatabase.replaceMediaReferences(context, 'journal', owners);
  }

  static journalReferences(books: JournalBook[]): Map<string, string[]> {
    const owners = new Map<string, string[]>();
    books.forEach((book: JournalBook) => {
      const ids: string[] = [];
      book.pages.forEach(page => page.elements.forEach((element: JournalElement) => {
        if (element.assetId && ids.indexOf(element.assetId) < 0) ids.push(element.assetId);
      }));
      owners.set(book.id, PersistencePolicy.uniqueAssetIds(ids));
    });
    return owners;
  }

  static async preparePostDrafts(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<PostDraft[]> {
    const prepared: PostDraft[] = JSON.parse(JSON.stringify(drafts)) as PostDraft[];
    for (const draft of prepared) {
      const current = draft.imageAssetId ? await BirdfolioDatabase.findMediaAsset(context, draft.imageAssetId) : null;
      const asset = current || await MediaAssetService.tryImport(context, draft.imageUri);
      if (asset) { draft.imageAssetId = asset.id; draft.imageUri = asset.previewUri; }
    }
    return prepared;
  }

  static async syncPostDraftReferences(context: common.UIAbilityContext, drafts: PostDraft[]): Promise<void> {
    const owners = MediaAssetService.postDraftReferences(drafts);
    await BirdfolioDatabase.replaceMediaReferences(context, 'postDraft', owners);
  }

  static postDraftReferences(drafts: PostDraft[]): Map<string, string[]> {
    const owners = new Map<string, string[]>();
    drafts.forEach((draft: PostDraft) => owners.set(draft.id, draft.imageAssetId ? [draft.imageAssetId] : []));
    return owners;
  }

  static async importImage(context: common.UIAbilityContext, sourceUri: string): Promise<MediaAsset> {
    const bytes = MediaAssetService.readSource(sourceUri);
    const kind = MediaAssetService.imageKind(bytes);
    const sha256 = await MediaAssetService.sha256(bytes);
    const existing = await BirdfolioDatabase.findMediaAssetByHash(context, sha256);
    if (existing) return existing;

    const source = image.createImageSource(bytes.buffer as ArrayBuffer);
    try {
      const info = await source.getImageInfo();
      if (info.size.width * info.size.height > MAX_IMPORT_PIXELS) throw new Error('IMAGE_PIXEL_LIMIT_EXCEEDED');
      const id = 'asset-' + Date.now().toString() + '-' + sha256.substring(0, 12);
      const root = context.filesDir + '/media';
      const originals = root + '/original'; const thumbs = root + '/thumbnail'; const previews = root + '/preview';
      fs.mkdirSync(originals, true); fs.mkdirSync(thumbs, true); fs.mkdirSync(previews, true);
      const originalPath = originals + '/' + id + '.' + kind.extension;
      const thumbnailPath = thumbs + '/' + id + '.jpg'; const previewPath = previews + '/' + id + '.jpg';
      try {
        MediaAssetService.writeFile(originalPath, bytes);
        await MediaAssetService.writeDerivative(source, info.size, thumbnailPath, 512, 74);
        await MediaAssetService.writeDerivative(source, info.size, previewPath, 2048, 88);
      } catch (error) {
        MediaAssetService.removeFile(originalPath); MediaAssetService.removeFile(thumbnailPath); MediaAssetService.removeFile(previewPath);
        throw new Error(String(error));
      }
      const asset: MediaAsset = {
        id: id, originalUri: fileUri.getUriFromPath(originalPath), thumbnailUri: fileUri.getUriFromPath(thumbnailPath),
        previewUri: fileUri.getUriFromPath(previewPath), mimeType: kind.mimeType, byteSize: bytes.byteLength,
        width: info.size.width, height: info.size.height, sha256: sha256, createdAt: Date.now()
      };
      await BirdfolioDatabase.saveMediaAsset(context, asset);
      return asset;
    } finally { source.release(); }
  }

  static async resolve(context: common.UIAbilityContext, assetId: string, preferred: 'original' | 'preview' | 'thumbnail' = 'preview'): Promise<string> {
    const asset = await BirdfolioDatabase.findMediaAsset(context, assetId);
    if (!asset) return '';
    if (preferred === 'original') return asset.originalUri;
    if (preferred === 'thumbnail') return asset.thumbnailUri;
    return asset.previewUri;
  }

  static async addReference(context: common.UIAbilityContext, assetId: string,
    ownerType: MediaReferenceOwnerType, ownerId: string): Promise<void> {
    const reference: MediaReference = { assetId: assetId, ownerType: ownerType, ownerId: ownerId, createdAt: Date.now() };
    await BirdfolioDatabase.addMediaReference(context, reference);
  }

  static async removeReference(context: common.UIAbilityContext, assetId: string,
    ownerType: MediaReferenceOwnerType, ownerId: string): Promise<void> {
    await BirdfolioDatabase.removeMediaReference(context, assetId, ownerType, ownerId);
  }

  static async cleanup(context: common.UIAbilityContext, graceMs: number = DEFAULT_ORPHAN_GRACE_MS): Promise<MediaCleanupResult> {
    const candidates = await BirdfolioDatabase.orphanedMedia(context, PersistencePolicy.orphanCutoff(Date.now(), graceMs));
    const result: MediaCleanupResult = { scanned: candidates.length, removed: 0, skipped: 0 };
    for (const asset of candidates) {
      try {
        MediaAssetService.removeFile(asset.originalUri); MediaAssetService.removeFile(asset.thumbnailUri); MediaAssetService.removeFile(asset.previewUri);
        await BirdfolioDatabase.deleteMediaAsset(context, asset.id); result.removed += 1;
      } catch (_error) { result.skipped += 1; }
    }
    return result;
  }

  private static readSource(uri: string): Uint8Array {
    const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      if (stat.size <= 0 || stat.size > MAX_IMPORT_BYTES) throw new Error('IMAGE_SIZE_LIMIT_EXCEEDED');
      const bytes = new Uint8Array(stat.size); const read = fs.readSync(file.fd, bytes.buffer);
      if (read !== stat.size) throw new Error('IMAGE_READ_INCOMPLETE');
      return bytes;
    } finally { fs.closeSync(file); }
  }

  private static async tryImport(context: common.UIAbilityContext, uri: string): Promise<MediaAsset | null> {
    if (!uri || uri.startsWith('data:') || uri.startsWith('http://') || uri.startsWith('https://') || uri.startsWith('resource://')) return null;
    try { return await MediaAssetService.importImage(context, uri); } catch (_error) { return null; }
  }

  private static async writeDerivative(source: image.ImageSource, size: image.Size, path: string,
    maxEdge: number, quality: number): Promise<void> {
    const longest = Math.max(size.width, size.height); const ratio = longest > maxEdge ? maxEdge / longest : 1;
    const desired: image.Size = { width: Math.max(1, Math.round(size.width * ratio)), height: Math.max(1, Math.round(size.height * ratio)) };
    const options: image.DecodingOptions = { desiredSize: desired };
    const pixelMap = await source.createPixelMap(options); const packer = image.createImagePacker();
    try {
      const packing: image.PackingOption = { format: 'image/jpeg', quality: quality };
      const data = await packer.packToData(pixelMap, packing); MediaAssetService.writeFile(path, new Uint8Array(data));
    } finally { pixelMap.release(); packer.release(); }
  }

  private static writeFile(path: string, bytes: Uint8Array): void {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, bytes.buffer); } finally { fs.closeSync(file); }
  }

  private static removeFile(uri: string): void {
    const path = uri.startsWith('file://') ? decodeURIComponent(uri.substring(7)) : uri;
    try { fs.unlinkSync(path); } catch (_error) {}
  }

  private static async sha256(bytes: Uint8Array): Promise<string> {
    const md = cryptoFramework.createMd('SHA256'); await md.update({ data: bytes }); const digest = await md.digest();
    let value = ''; digest.data.forEach((item: number) => { value += item.toString(16).padStart(2, '0'); }); return value;
  }

  private static imageKind(bytes: Uint8Array): ImageKind {
    if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) return { mimeType: 'image/png', extension: 'png' };
    if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return { mimeType: 'image/jpeg', extension: 'jpg' };
    if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 && bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return { mimeType: 'image/webp', extension: 'webp' };
    throw new Error('UNSUPPORTED_IMAGE_TYPE');
  }
}
