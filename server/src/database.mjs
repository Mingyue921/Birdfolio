import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { migrateDatabase } from './migrations.mjs';

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
  const databaseFactory = options.databaseFactory || (path => new DatabaseSync(path));
  const db = databaseFactory(filePath);
  try {
    db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
    (options.migrateImpl || migrateDatabase)(db, { logger: options.logger, migrationList: options.migrationList });
    if (options.seed !== false) {
      const insert = db.prepare(`INSERT OR IGNORE INTO posts
        (id,user_id,author_name,type,title,body,species_id,behavior,place_name,visibility,image_url,created_at,updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`);
      for (const post of seedPosts) {
        insert.run(post.id, post.userId, post.authorName, post.type, post.title, post.body, post.speciesId,
          post.behavior, post.placeName, post.visibility, post.imageUrl, post.createdAt, post.createdAt);
      }
    }
    db.dialect = 'sqlite';
    db.health = async () => { db.prepare('SELECT 1').get(); return true; };
    db.transaction = async callback => {
      db.exec('BEGIN IMMEDIATE');
      try { const result = await callback(db); db.exec('COMMIT'); return result; }
      catch (error) { try { db.exec('ROLLBACK'); } catch { /* preserve original error */ } throw error; }
    };
    return db;
  } catch (error) {
    try { db.close(); } catch { /* preserve the initialization error */ }
    throw error;
  }
}

export async function postRows(db, where = '', params = [], viewerId = 'demo-user') {
  const rows = await db.prepare(`SELECT p.*,
    COALESCE(SUM(r.liked),0) AS like_count, COALESCE(SUM(r.favorite),0) AS favorite_count,
    (SELECT COUNT(*) FROM comments c WHERE c.post_id=p.id) AS comment_count
    FROM posts p LEFT JOIN reactions r ON r.post_id=p.id ${where}
    GROUP BY p.id ORDER BY p.created_at DESC`).all(...params);
  const result = rows.map(row => ({
    id: row.id, userId: row.user_id, authorName: row.author_name, type: row.type,
    title: row.title, body: row.body, speciesId: row.species_id, behavior: row.behavior,
    placeName: row.place_name, visibility: row.visibility, imageUrl: row.image_url,
    createdAt: row.created_at, updatedAt: row.updated_at,
    likeCount: Number(row.like_count), favoriteCount: Number(row.favorite_count), commentCount: Number(row.comment_count),
    liked: false, favorited: false
  }));
  for (const item of result) {
    item.liked = Boolean((await db.prepare('SELECT liked FROM reactions WHERE post_id=? AND user_id=?').get(item.id, viewerId))?.liked);
    item.favorited = Boolean((await db.prepare('SELECT favorite FROM reactions WHERE post_id=? AND user_id=?').get(item.id, viewerId))?.favorite);
  }
  return result;
}
