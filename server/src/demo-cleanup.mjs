export async function cleanupExpiredDemoAccounts(db, { now = Date.now(), storage, logger } = {}) {
  const accounts = await db.prepare('SELECT user_id,expires_at FROM demo_accounts WHERE expires_at<=? ORDER BY expires_at').all(now);
  let removed = 0; let skipped = 0;
  for (const account of accounts) {
    const media = await db.prepare('SELECT id,file_name FROM media WHERE user_id=? AND deleted_at=0').all(account.user_id);
    let mediaReady = true;
    for (const item of media) {
      try { if (storage && !await storage.deleteObject(item.file_name)) mediaReady = false; }
      catch { mediaReady = false; }
    }
    if (!mediaReady) { skipped += 1; continue; }
    await db.transaction(async tx => {
      await tx.prepare('DELETE FROM identify_feedback WHERE request_id IN (SELECT id FROM identify_requests WHERE user_id=?)').run(account.user_id);
      await tx.prepare('DELETE FROM identify_requests WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM observations WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM sync_operations WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM reactions WHERE user_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(account.user_id, account.user_id);
      await tx.prepare('DELETE FROM comments WHERE user_id=? OR post_id IN (SELECT id FROM posts WHERE user_id=?)').run(account.user_id, account.user_id);
      await tx.prepare('DELETE FROM posts WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM content_reports WHERE reporter_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM user_blocks WHERE blocker_id=? OR blocked_user_id=?').run(account.user_id, account.user_id);
      await tx.prepare('DELETE FROM media WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM sessions WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM demo_accounts WHERE user_id=?').run(account.user_id);
      await tx.prepare('DELETE FROM users WHERE id=?').run(account.user_id);
    });
    removed += 1;
  }
  const result = { scanned: accounts.length, removed, skipped };
  logger?.info('demo_accounts.cleanup_completed', result); return result;
}

export function scheduleDemoCleanup(db, options = {}) {
  const intervalMs = Math.max(60_000, Number(options.intervalMs || 30 * 60 * 1000));
  const run = async () => { try { await cleanupExpiredDemoAccounts(db, options); } catch (error) { options.logger?.error('demo_accounts.cleanup_failed', { errorCategory: 'cleanup', message: String(error?.message || error) }); } };
  const timer = setInterval(run, intervalMs); timer.unref?.();
  return () => clearInterval(timer);
}
