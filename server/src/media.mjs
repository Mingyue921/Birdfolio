import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, unlinkSync } from 'node:fs';

export const MAX_MEDIA_BYTES = 8 * 1024 * 1024;
export const MAX_IMAGE_PIXELS = 24_000_000;

function imageDimensions(buffer, mime) {
  if (mime === 'image/png') {
    if (buffer.length < 33 || !buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return { width: 0, height: 0, valid: false };
    if (buffer.readUInt32BE(8) !== 13 || buffer.toString('ascii', 12, 16) !== 'IHDR') return { width: 0, height: 0, valid: false };
    const width = buffer.readUInt32BE(16); const height = buffer.readUInt32BE(20); let offset = 8; let ended = false;
    while (offset + 12 <= buffer.length) {
      const length = buffer.readUInt32BE(offset); const end = offset + 12 + length;
      if (end > buffer.length) return { width: 0, height: 0, valid: false };
      if (buffer.toString('ascii', offset + 4, offset + 8) === 'IEND') { ended = true; break; }
      offset = end;
    }
    return { width, height, valid: width > 0 && height > 0 && ended };
  }
  if (mime === 'image/webp') {
    if (buffer.length < 20 || buffer.toString('ascii', 0, 4) !== 'RIFF' || buffer.toString('ascii', 8, 12) !== 'WEBP') return { width: 0, height: 0, valid: false };
    const kind = buffer.toString('ascii', 12, 16);
    if (kind === 'VP8X' && buffer.length >= 30) return { width: 1 + buffer.readUIntLE(24, 3), height: 1 + buffer.readUIntLE(27, 3), valid: true };
    if (kind === 'VP8 ' && buffer.length >= 30) {
      for (let offset = 20; offset + 10 < buffer.length; offset++) {
        if (buffer[offset] === 0x9d && buffer[offset + 1] === 0x01 && buffer[offset + 2] === 0x2a) {
          return { width: buffer.readUInt16LE(offset + 3) & 0x3fff, height: buffer.readUInt16LE(offset + 5) & 0x3fff, valid: true };
        }
      }
    }
    if (kind === 'VP8L' && buffer.length >= 25 && buffer[21] === 0x2f) {
      const bits = buffer.readUInt32LE(22); return { width: 1 + (bits & 0x3fff), height: 1 + ((bits >>> 14) & 0x3fff), valid: true };
    }
    return { width: 0, height: 0, valid: false };
  }
  if (mime === 'image/jpeg') {
    if (buffer.length < 4 || buffer[0] !== 0xff || buffer[1] !== 0xd8 || buffer[buffer.length - 2] !== 0xff || buffer[buffer.length - 1] !== 0xd9) return { width: 0, height: 0, valid: false };
    let offset = 2;
    while (offset + 9 < buffer.length) {
      if (buffer[offset] !== 0xff) { offset += 1; continue; }
      const marker = buffer[offset + 1]; offset += 2;
      if (marker === 0xd8 || marker === 0xd9 || (marker >= 0xd0 && marker <= 0xd7)) continue;
      if (offset + 2 > buffer.length) break;
      const length = buffer.readUInt16BE(offset); if (length < 2 || offset + length > buffer.length) break;
      const sof = (marker >= 0xc0 && marker <= 0xc3) || (marker >= 0xc5 && marker <= 0xc7) || (marker >= 0xc9 && marker <= 0xcb) || (marker >= 0xcd && marker <= 0xcf);
       if (sof && length >= 7) return { width: buffer.readUInt16BE(offset + 5), height: buffer.readUInt16BE(offset + 3), valid: true };
      offset += length;
    }
  }
  return { width: 0, height: 0, valid: false };
}

export function detectImageMime(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length < 12) return '';
  if (buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (buffer.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (buffer.toString('ascii', 0, 4) === 'RIFF' && buffer.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
  return '';
}

export function decodeDataUrl(value) {
  const match = String(value || '').match(/^data:(image\/(?:png|jpe?g|webp));base64,([A-Za-z0-9+/=\s]+)$/i);
  if (!match) throw new Error('INVALID_IMAGE');
  const buffer = Buffer.from(match[2].replace(/\s/g, ''), 'base64');
  return { buffer, mime: match[1].toLowerCase() === 'image/jpg' ? 'image/jpeg' : match[1].toLowerCase() };
}

export function validateImageBuffer(buffer, declaredMime = '') {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) throw new Error('INVALID_IMAGE');
  if (buffer.length > MAX_MEDIA_BYTES) throw new Error('INVALID_IMAGE_SIZE');
  const detected = detectImageMime(buffer);
  if (!detected || (declaredMime && detected !== declaredMime.toLowerCase().replace('image/jpg', 'image/jpeg'))) throw new Error('INVALID_IMAGE_MAGIC');
  const dimensions = imageDimensions(buffer, detected);
  if (!dimensions.valid || dimensions.width <= 0 || dimensions.height <= 0) throw new Error('INVALID_IMAGE_CONTENT');
  if (dimensions.width && dimensions.height && dimensions.width * dimensions.height > MAX_IMAGE_PIXELS) throw new Error('INVALID_IMAGE_PIXELS');
  return { mime: detected, width: dimensions.width, height: dimensions.height };
}

// Remove common metadata containers before persisting user media. This keeps the
// original pixels while avoiding EXIF GPS/camera data in short-lived uploads.
export function sanitizeImageBuffer(buffer, mime) {
  if (mime === 'image/jpeg' && buffer.length > 4) {
    const output = [buffer.subarray(0, 2)]; let offset = 2;
    while (offset + 4 <= buffer.length) {
      if (buffer[offset] !== 0xff) { output.push(buffer.subarray(offset)); break; }
      const marker = buffer[offset + 1];
      if (marker === 0xda) { output.push(buffer.subarray(offset)); break; }
      if (marker === 0xd8 || marker === 0xd9 || (marker >= 0xd0 && marker <= 0xd7)) { output.push(buffer.subarray(offset, offset + 2)); offset += 2; continue; }
      const length = buffer.readUInt16BE(offset + 2);
      if (length < 2 || offset + 2 + length > buffer.length) { output.push(buffer.subarray(offset)); break; }
      if (marker !== 0xe1) output.push(buffer.subarray(offset, offset + 2 + length));
      offset += 2 + length;
    }
    return Buffer.concat(output);
  }
  if (mime === 'image/png' && buffer.length > 32) {
    const output = [buffer.subarray(0, 8)]; let offset = 8;
    while (offset + 12 <= buffer.length) {
      const length = buffer.readUInt32BE(offset); const end = offset + 12 + length;
      if (end > buffer.length) return buffer;
      const type = buffer.toString('ascii', offset + 4, offset + 8);
      if (!['eXIf', 'tEXt', 'zTXt', 'iTXt'].includes(type)) output.push(buffer.subarray(offset, end));
      offset = end; if (type === 'IEND') break;
    }
    if (offset < buffer.length) output.push(buffer.subarray(offset));
    return Buffer.concat(output);
  }
  return buffer;
}

export async function saveMedia({ db, storage, userId, buffer, mime, ttlMs = 60 * 60 * 1000 }) {
  const info = validateImageBuffer(buffer, mime);
  buffer = sanitizeImageBuffer(buffer, info.mime);
  const id = `media-${Date.now()}-${randomBytes(8).toString('hex')}`;
  const extension = info.mime === 'image/png' ? 'png' : info.mime === 'image/webp' ? 'webp' : 'jpg';
  const fileName = `${id}.${extension}`;
  let stored;
  try { stored = await storage.putObject(fileName, buffer, info.mime); }
  catch { throw new Error('MEDIA_STORAGE_UNAVAILABLE'); }
  const createdAt = Date.now(); const expiresAt = createdAt + ttlMs;
  try {
    await db.prepare(`INSERT INTO media(id,user_id,file_name,mime_type,byte_size,file_path,created_at,expires_at,deleted_at)
      VALUES(?,?,?,?,?,?,?,?,0)`).run(id, userId, fileName, info.mime, buffer.length, stored.locator || fileName, createdAt, expiresAt);
  } catch (error) {
    try { await storage.deleteObject(fileName); } catch { /* preserve database failure */ }
    throw error;
  }
  return { id, mimeType: info.mime, byteSize: buffer.length, width: info.width, height: info.height, expiresAt, url: `/media/${fileName}` };
}

export async function getMedia(db, storage, mediaId, userId, { allowExpired = false } = {}) {
  const row = await db.prepare('SELECT * FROM media WHERE id=? AND user_id=? AND deleted_at=0').get(mediaId, userId);
  if (!row || (!allowExpired && row.expires_at <= Date.now())) return null;
  const buffer = await storage.getObject(row.file_name);
  return buffer ? { row, buffer } : null;
}

export async function removeStoredMedia(storage, row) {
  if (!row?.file_name) return true;
  try { return await storage.deleteObject(row.file_name); }
  catch { return false; }
}

export function removeMediaFile(row) {
  if (!row?.file_path || !existsSync(row.file_path)) return true;
  try { unlinkSync(row.file_path); return true; }
  catch { return false; }
}
