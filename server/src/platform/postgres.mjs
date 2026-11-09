import pg from 'pg';

const { Pool } = pg;

function placeholders(sql) {
  let index = 0;
  return sql.replace(/\?/g, () => `$${++index}`);
}

function statement(pool, sql) {
  const text = placeholders(sql);
  return {
    async get(...params) { return (await pool.query(text, params)).rows[0]; },
    async all(...params) { return (await pool.query(text, params)).rows; },
    async run(...params) {
      const result = await pool.query(text, params);
      return { changes: result.rowCount, rows: result.rows };
    }
  };
}

export function createPostgresAdapter(pool) {
  return {
    dialect: 'postgres',
    prepare(sql) { return statement(pool, sql); },
    async exec(sql) { await pool.query(sql); },
    async transaction(callback) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const result = await callback(createPostgresAdapter(client));
        await client.query('COMMIT');
        return result;
      } catch (error) {
        try { await client.query('ROLLBACK'); } catch { /* preserve original error */ }
        throw error;
      } finally { client.release?.(); }
    },
    async health() { await pool.query('SELECT 1'); return true; },
    async close() { await pool.end(); }
  };
}

export async function openPostgresDatabase(env, options = {}) {
  const connectionString = String(env.DATABASE_URL || '').trim();
  if (!connectionString) throw new Error('DATABASE_URL_REQUIRED');
  const pool = options.pool || new Pool({
    connectionString,
    max: Math.max(1, Number(env.DATABASE_POOL_SIZE || 10)),
    idleTimeoutMillis: Math.max(1000, Number(env.DATABASE_IDLE_TIMEOUT_MS || 30000)),
    connectionTimeoutMillis: Math.max(1000, Number(env.DATABASE_CONNECT_TIMEOUT_MS || 5000)),
    ssl: String(env.DATABASE_SSL || 'true').toLowerCase() === 'false' ? false : { rejectUnauthorized: String(env.DATABASE_SSL_REJECT_UNAUTHORIZED || 'true').toLowerCase() !== 'false' }
  });
  const adapter = createPostgresAdapter(pool);
  try { await adapter.health(); return adapter; }
  catch (error) { await adapter.close().catch(() => {}); throw error; }
}
