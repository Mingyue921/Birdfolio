import { removeMediaFile } from './media.mjs';

export function cleanupExpiredMedia(db, { now = Date.now(), logger } = {}) {
  const rows = db.prepare(`SELECT * FROM media
    WHERE deleted_at=0 AND expires_at<=?
    AND NOT EXISTS (SELECT 1 FROM posts WHERE image_url='/media/' || media.file_name)`)
    .all(now);
  let removed = 0;
  for (const row of rows) {
    removeMediaFile(row);
    db.prepare('UPDATE media SET deleted_at=? WHERE id=? AND deleted_at=0').run(now, row.id);
    removed += 1;
  }
  if (removed > 0) logger?.info('media.cleanup_completed', { removed, cutoff: now });
  return { scanned: rows.length, removed };
}

export function scheduleMediaCleanup(db, options = {}) {
  const intervalMs = Math.max(1000, Number(options.intervalMs || 15 * 60 * 1000));
  const run = () => {
    try { cleanupExpiredMedia(db, { logger: options.logger }); }
    catch (error) { options.logger?.error('media.cleanup_failed', { error: String(error?.message || error) }); }
  };
  run();
  const timer = setInterval(run, intervalMs);
  timer.unref?.();
  return () => clearInterval(timer);
}
