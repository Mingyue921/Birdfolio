const migrations = [
  {
    version: 1,
    name: 'production_schema',
    sql: `
      CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL DEFAULT '');
      CREATE TABLE IF NOT EXISTS auth_codes (id TEXT PRIMARY KEY, email TEXT NOT NULL, code_hash TEXT NOT NULL, expires_at BIGINT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, used_at BIGINT NOT NULL DEFAULT 0, created_at BIGINT NOT NULL, request_ip TEXT NOT NULL DEFAULT '');
      CREATE INDEX IF NOT EXISTS auth_codes_email_created ON auth_codes(email, created_at DESC);
      CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, access_token_hash TEXT NOT NULL UNIQUE, refresh_token_hash TEXT NOT NULL UNIQUE, access_expires_at BIGINT NOT NULL, refresh_expires_at BIGINT NOT NULL, created_at BIGINT NOT NULL, revoked_at BIGINT NOT NULL DEFAULT 0);
      CREATE INDEX IF NOT EXISTS sessions_access ON sessions(access_token_hash);
      CREATE INDEX IF NOT EXISTS sessions_refresh ON sessions(refresh_token_hash);
      CREATE TABLE IF NOT EXISTS posts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, author_name TEXT NOT NULL, type TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, species_id TEXT NOT NULL, behavior TEXT NOT NULL, place_name TEXT NOT NULL, visibility TEXT NOT NULL, image_url TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS comments (id TEXT PRIMARY KEY, post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE, user_id TEXT NOT NULL, author_name TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS reactions (post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE, user_id TEXT NOT NULL, liked INTEGER NOT NULL DEFAULT 0, favorite INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL, PRIMARY KEY(post_id,user_id));
      CREATE TABLE IF NOT EXISTS observations (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL DEFAULT '', version INTEGER NOT NULL DEFAULT 1);
      CREATE TABLE IF NOT EXISTS media (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, file_name TEXT NOT NULL, mime_type TEXT NOT NULL, byte_size BIGINT NOT NULL, file_path TEXT NOT NULL, created_at BIGINT NOT NULL, expires_at BIGINT NOT NULL, deleted_at BIGINT NOT NULL DEFAULT 0);
      CREATE INDEX IF NOT EXISTS media_user_created ON media(user_id, created_at DESC);
      CREATE TABLE IF NOT EXISTS identify_requests (id TEXT PRIMARY KEY, user_id TEXT NOT NULL, media_id TEXT NOT NULL DEFAULT '', status TEXT NOT NULL, mode TEXT NOT NULL DEFAULT 'unavailable', result_json TEXT NOT NULL DEFAULT '{}', warning TEXT NOT NULL DEFAULT '', model_version TEXT NOT NULL DEFAULT '', created_at BIGINT NOT NULL, updated_at BIGINT NOT NULL, confirmed_at BIGINT NOT NULL DEFAULT 0);
      CREATE TABLE IF NOT EXISTS identify_feedback (id TEXT PRIMARY KEY, request_id TEXT NOT NULL REFERENCES identify_requests(id) ON DELETE CASCADE, user_id TEXT NOT NULL, species_id TEXT NOT NULL DEFAULT '', rating TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT '', created_at BIGINT NOT NULL);
      CREATE TABLE IF NOT EXISTS sync_operations (idempotency_key TEXT NOT NULL, user_id TEXT NOT NULL, response_json TEXT NOT NULL, created_at BIGINT NOT NULL, PRIMARY KEY(user_id,idempotency_key));
      CREATE TABLE IF NOT EXISTS content_reports (id TEXT PRIMARY KEY, reporter_id TEXT NOT NULL, post_id TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at BIGINT NOT NULL);
      CREATE TABLE IF NOT EXISTS user_blocks (blocker_id TEXT NOT NULL, blocked_user_id TEXT NOT NULL, created_at BIGINT NOT NULL, PRIMARY KEY(blocker_id,blocked_user_id));
      CREATE TABLE IF NOT EXISTS rate_limits (bucket_key TEXT PRIMARY KEY, started_at BIGINT NOT NULL, request_count INTEGER NOT NULL);
    `
  },
  {
    version: 2,
    name: 'competition_demo_accounts',
    sql: `CREATE TABLE IF NOT EXISTS demo_accounts (
      user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      expires_at BIGINT NOT NULL, created_at BIGINT NOT NULL
    ); CREATE INDEX IF NOT EXISTS demo_accounts_expiry ON demo_accounts(expires_at);`
  }
];

export async function migratePostgres(db, { logger, migrationList = migrations } = {}) {
  await db.exec('CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL)');
  const applied = new Set((await db.prepare('SELECT version FROM schema_migrations').all()).map(row => Number(row.version)));
  for (const migration of [...migrationList].sort((left, right) => left.version - right.version)) {
    if (applied.has(migration.version)) continue;
    await db.transaction(async tx => {
      await tx.exec(migration.sql);
      await tx.prepare('INSERT INTO schema_migrations(version,name,applied_at) VALUES(?,?,?)').run(migration.version, migration.name, new Date().toISOString());
    });
    logger?.info('database.migration_applied', { dialect: 'postgres', version: migration.version, name: migration.name });
  }
}

export { migrations as postgresMigrations };
