export function createPersistentRateLimiter(db) {
  return async function enforceRate(key, limit, windowMs) {
    const now = Date.now();
    if (db.dialect === 'postgres') {
      const result = await db.prepare(`INSERT INTO rate_limits(bucket_key,started_at,request_count) VALUES(?,?,1)
        ON CONFLICT(bucket_key) DO UPDATE SET started_at=CASE WHEN rate_limits.started_at+?<=? THEN ? ELSE rate_limits.started_at END,
        request_count=CASE WHEN rate_limits.started_at+?<=? THEN 1 ELSE rate_limits.request_count+1 END RETURNING request_count`).run(key, now, windowMs, now, now, windowMs, now);
      if (Number(result.rows?.[0]?.request_count || 0) > limit) throw new Error('RATE_LIMITED');
      return;
    }
    await db.prepare('CREATE TABLE IF NOT EXISTS rate_limits(bucket_key TEXT PRIMARY KEY, started_at INTEGER NOT NULL, request_count INTEGER NOT NULL)').run();
    const current = await db.prepare('SELECT started_at,request_count FROM rate_limits WHERE bucket_key=?').get(key);
    if (!current || Number(current.started_at) + windowMs <= now) await db.prepare('INSERT INTO rate_limits(bucket_key,started_at,request_count) VALUES(?,?,1) ON CONFLICT(bucket_key) DO UPDATE SET started_at=excluded.started_at,request_count=1').run(key, now);
    else {
      const count = Number(current.request_count) + 1;
      await db.prepare('UPDATE rate_limits SET request_count=? WHERE bucket_key=?').run(count, key);
      if (count > limit) throw new Error('RATE_LIMITED');
    }
  };
}
