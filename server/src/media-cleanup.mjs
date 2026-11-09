import { removeStoredMedia } from './media.mjs';

export async function cleanupExpiredMedia(db, { now = Date.now(), logger, storage } = {}) {
  if (!storage) throw new Error('MEDIA_STORAGE_REQUIRED');
  const rows = await db.prepare(`SELECT media.*,
    EXISTS (SELECT 1 FROM posts WHERE image_url='/media/' || media.file_name) AS referenced
    FROM media WHERE deleted_at=0`).all();
  let removed = 0;
  for (const row of rows) {
    if (row.expires_at > now || row.referenced) continue;
    if (!await removeStoredMedia(storage, row)) continue;
    await db.prepare('UPDATE media SET deleted_at=? WHERE id=? AND deleted_at=0').run(now, row.id);
    removed += 1;
  }
  const result = { scanned: rows.length, removed, skipped: rows.length - removed };
  logger?.info('media.cleanup_completed', result);
  return result;
}

export function scheduleMediaCleanup(db, options = {}) {
  const intervalMs = Math.max(1000, Number(options.intervalMs || 15 * 60 * 1000));
  const run = async () => {
    try { await cleanupExpiredMedia(db, { logger: options.logger, storage: options.storage }); }
    catch (error) { options.logger?.error('media.cleanup_failed', { error: String(error?.message || error) }); }
  };
  run();
  const timer = setInterval(run, intervalMs);
  timer.unref?.();
  return () => clearInterval(timer);
}
