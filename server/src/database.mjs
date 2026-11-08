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
  const db = new DatabaseSync(filePath);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');
  migrateDatabase(db, { logger: options.logger });
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
