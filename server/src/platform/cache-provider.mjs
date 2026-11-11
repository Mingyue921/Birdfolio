function positiveTtl(value) { return Math.max(1, Math.floor(Number(value) || 1)); }

export function createMemoryCache(options = {}) {
  const clock = options.clock || Date.now;
  const values = new Map();
  function current(key) {
    const entry = values.get(key);
    if (!entry) return null;
    if (entry.expiresAt <= clock()) { values.delete(key); return null; }
    return entry;
  }
  return {
    kind: 'memory',
    async get(key) { return current(String(key))?.value ?? null; },
    async set(key, value, ttlSeconds) { values.set(String(key), { value: String(value), expiresAt: clock() + positiveTtl(ttlSeconds) * 1000 }); },
    async delete(key) { return values.delete(String(key)); },
    async increment(key, ttlSeconds) {
      const name = String(key); const entry = current(name); const count = Number(entry?.value || 0) + 1;
      values.set(name, { value: String(count), expiresAt: entry?.expiresAt || clock() + positiveTtl(ttlSeconds) * 1000 });
      return count;
    },
    async health() { return true; },
    async close() { values.clear(); }
  };
}

export async function createRedisCache(env, options = {}) {
  const url = String(env.REDIS_URL || env.DCS_REDIS_URL || '').trim();
  if (!url) throw new Error('REDIS_URL_REQUIRED');
  const module = options.redisModule || await import('redis');
  const client = options.client || module.createClient({ url, socket: { connectTimeout: Math.max(1000, Number(env.REDIS_CONNECT_TIMEOUT_MS || 5000)), tls: url.startsWith('rediss://') } });
  client.on?.('error', error => options.logger?.error?.('redis.error', { errorCategory: 'dependency', message: String(error?.message || error) }));
  if (!client.isOpen) await client.connect();
  const prefix = String(env.REDIS_KEY_PREFIX || 'birdfolio:').replace(/:+$/, '') + ':';
  const key = value => prefix + String(value).replace(/[^a-zA-Z0-9:_-]/g, '_');
  return {
    kind: 'redis',
    async get(name) { return client.get(key(name)); },
    async set(name, value, ttlSeconds) { await client.set(key(name), String(value), { EX: positiveTtl(ttlSeconds) }); },
    async delete(name) { return Number(await client.del(key(name))) > 0; },
    async increment(name, ttlSeconds) {
      return Number(await client.eval("local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]); end; return n", { keys: [key(name)], arguments: [String(positiveTtl(ttlSeconds))] }));
    },
    async health() { return (await client.ping()) === 'PONG'; },
    async close() { if (client.isOpen) await client.quit(); }
  };
}

export async function createCacheProvider(env = {}, options = {}) {
  const provider = String(env.CACHE_PROVIDER || (env.REDIS_URL || env.DCS_REDIS_URL ? 'redis' : 'memory')).toLowerCase();
  if (provider === 'memory') return createMemoryCache(options);
  if (provider === 'redis') return createRedisCache(env, options);
  throw new Error('CACHE_PROVIDER_UNSUPPORTED');
}

export function createCacheRateLimiter(cache) {
  return async function enforceRate(key, limit, windowMs) {
    try {
      const count = await cache.increment(`rate:${key}`, Math.ceil(Number(windowMs) / 1000));
      if (count > Number(limit)) throw new Error('RATE_LIMITED');
    } catch (error) {
      if (String(error?.message || error) === 'RATE_LIMITED') throw error;
      throw new Error('RATE_LIMIT_DEPENDENCY_UNAVAILABLE');
    }
  };
}
