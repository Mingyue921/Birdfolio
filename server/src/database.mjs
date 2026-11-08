import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';

const seedPosts = [
  {
    id: 'post-seed-egret', userId: 'forest-letter', authorName: '林间来信', type: 'photo',
    title: '浅滩上的白色访客', body: '清晨的白鹭沿着浅滩缓慢觅食，等了二十分钟，终于看见它捕到一尾银亮的小鱼。',
    speciesId: 'egret', behavior: '觅食', placeName: '北京海淀', visibility: '所有人',
    imageUrl: '/seed/community_egret', createdAt: '2026-09-09T06:32:00.000Z'
  },
  {
    id: 'post-seed-journal', userId: 'feather-note', authorName: '羽色笔记', type: 'journal',
    title: '把相遇留在纸上', body: '把这次遇见做成一页手账，也记下了当时的风和水声。',
    speciesId: 'egret', behavior: '休息', placeName: '杭州西湖', visibility: '所有人',
    imageUrl: '/seed/community_journal', createdAt: '2026-09-08T09:20:00.000Z'
  }
];

export function openDatabase(filePath, options = {}) {
  mkdirSync(dirname(filePath), { recursive: true });
  const db = new DatabaseSync(filePath);
  db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
    CREATE TABLE IF NOT EXISTS posts (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, author_name TEXT NOT NULL, type TEXT NOT NULL,
      title TEXT NOT NULL, body TEXT NOT NULL, species_id TEXT NOT NULL, behavior TEXT NOT NULL,
      place_name TEXT NOT NULL, visibility TEXT NOT NULL, image_url TEXT NOT NULL,
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS comments (
      id TEXT PRIMARY KEY, post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL, author_name TEXT NOT NULL, body TEXT NOT NULL, created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS reactions (
      post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE, user_id TEXT NOT NULL,
      liked INTEGER NOT NULL DEFAULT 0, favorite INTEGER NOT NULL DEFAULT 0, updated_at TEXT NOT NULL,
      PRIMARY KEY (post_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS observations (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL,
      deleted_at TEXT NOT NULL DEFAULT '', version INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE, display_name TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT NOT NULL DEFAULT ''
    );
    CREATE TABLE IF NOT EXISTS auth_codes (
      id TEXT PRIMARY KEY, email TEXT NOT NULL, code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL,
      attempts INTEGER NOT NULL DEFAULT 0, used_at INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL, request_ip TEXT NOT NULL DEFAULT ''
    );
    CREATE INDEX IF NOT EXISTS auth_codes_email_created ON auth_codes(email, created_at DESC);
    CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      access_token_hash TEXT NOT NULL UNIQUE, refresh_token_hash TEXT NOT NULL UNIQUE,
      access_expires_at INTEGER NOT NULL, refresh_expires_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL, revoked_at INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS sessions_access ON sessions(access_token_hash);
    CREATE INDEX IF NOT EXISTS sessions_refresh ON sessions(refresh_token_hash);
    CREATE TABLE IF NOT EXISTS media (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, file_name TEXT NOT NULL, mime_type TEXT NOT NULL,
      byte_size INTEGER NOT NULL, file_path TEXT NOT NULL, created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL, deleted_at INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS media_user_created ON media(user_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS identify_requests (
      id TEXT PRIMARY KEY, user_id TEXT NOT NULL, media_id TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL, mode TEXT NOT NULL DEFAULT 'unavailable', result_json TEXT NOT NULL DEFAULT '{}',
      warning TEXT NOT NULL DEFAULT '', model_version TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, confirmed_at INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS identify_user_created ON identify_requests(user_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS identify_feedback (
      id TEXT PRIMARY KEY, request_id TEXT NOT NULL REFERENCES identify_requests(id) ON DELETE CASCADE,
      user_id TEXT NOT NULL, species_id TEXT NOT NULL DEFAULT '', rating TEXT NOT NULL DEFAULT '',
      reason TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS sync_operations (
      idempotency_key TEXT NOT NULL, user_id TEXT NOT NULL, response_json TEXT NOT NULL,
      created_at INTEGER NOT NULL, PRIMARY KEY (user_id, idempotency_key)
    );
    CREATE TABLE IF NOT EXISTS content_reports (
      id TEXT PRIMARY KEY, reporter_id TEXT NOT NULL, post_id TEXT NOT NULL,
      reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'open', created_at INTEGER NOT NULL
    );
    CREATE INDEX IF NOT EXISTS content_reports_post ON content_reports(post_id, created_at DESC);
    CREATE TABLE IF NOT EXISTS user_blocks (
      blocker_id TEXT NOT NULL, blocked_user_id TEXT NOT NULL, created_at INTEGER NOT NULL,
      PRIMARY KEY (blocker_id, blocked_user_id)
    );
  `);
  // Older development databases predate the observation version column. SQLite has no
  // IF NOT EXISTS form for ALTER TABLE, so inspect the table before adding it.
  const observationColumns = db.prepare('PRAGMA table_info(observations)').all().map(row => row.name);
  if (!observationColumns.includes('version')) db.exec('ALTER TABLE observations ADD COLUMN version INTEGER NOT NULL DEFAULT 1');
  if (options.seed !== false) {
  const insert = db.prepare(`INSERT OR IGNORE INTO posts
    (id,user_id,author_name,type,title,body,species_id,behavior,place_name,visibility,image_url,created_at,updated_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`);
  for (const post of seedPosts) {
    insert.run(post.id, post.userId, post.authorName, post.type, post.title, post.body, post.speciesId,
      post.behavior, post.placeName, post.visibility, post.imageUrl, post.createdAt, post.createdAt);
  }
  }
  return db;
}

export function postRows(db, where = '', params = [], viewerId = 'demo-user') {
  const rows = db.prepare(`SELECT p.*,
    COALESCE(SUM(r.liked),0) AS like_count, COALESCE(SUM(r.favorite),0) AS favorite_count,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id) AS comment_count
    FROM posts p LEFT JOIN reactions r ON r.post_id=p.id ${where}
    GROUP BY p.id ORDER BY p.created_at DESC`).all(...params);
  return rows.map(row => ({
    id: row.id, userId: row.user_id, authorName: row.author_name, type: row.type,
    title: row.title, body: row.body, speciesId: row.species_id, behavior: row.behavior,
    placeName: row.place_name, visibility: row.visibility, imageUrl: row.image_url,
    createdAt: row.created_at, updatedAt: row.updated_at,
    likeCount: Number(row.like_count), favoriteCount: Number(row.favorite_count), commentCount: Number(row.comment_count),
    liked: Boolean(db.prepare('SELECT liked FROM reactions WHERE post_id=? AND user_id=?').get(row.id, viewerId)?.liked),
    favorited: Boolean(db.prepare('SELECT favorite FROM reactions WHERE post_id=? AND user_id=?').get(row.id, viewerId)?.favorite)
  }));
}
