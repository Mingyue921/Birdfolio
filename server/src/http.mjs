import { randomBytes } from 'node:crypto';

export function requestId(req) {
  return String(req.headers['x-request-id'] || `req-${Date.now()}-${randomBytes(4).toString('hex')}`)
    .replace(/[^a-zA-Z0-9_.:-]/g, '_').slice(0, 96);
}

export function json(res, status, value, env = {}, id = '') {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    ...corsHeaders(env),
    'x-request-id': id || `req-${Date.now()}`
  });
  res.end(JSON.stringify(value));
}

export function corsHeaders(env = {}) {
  return {
    'access-control-allow-origin': String(env.CORS_ORIGIN || '*').trim() || '*',
    'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'access-control-allow-headers': 'content-type,authorization,idempotency-key,x-request-id'
  };
}

export function handleCorsPreflight(req, res, env = {}, id = '') {
  if (req.method !== 'OPTIONS') return false;
  res.writeHead(204, { ...corsHeaders(env), 'x-request-id': id || `req-${Date.now()}` });
  res.end();
  return true;
}

export async function rawBody(req, maxBytes = 5 * 1024 * 1024) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) throw new Error('PAYLOAD_TOO_LARGE');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export async function body(req, maxBytes = 5 * 1024 * 1024) {
  const bytes = await rawBody(req, maxBytes);
  if (!bytes.length) return {};
  try { return JSON.parse(bytes.toString('utf8')); }
  catch { throw new Error('INVALID_JSON'); }
}

export function required(value, name) {
  const text = String(value || '').trim();
  if (!text) throw new Error(`MISSING_${name}`);
  return text;
}

export function errorStatus(message) {
  if (message === 'PAYLOAD_TOO_LARGE') return 413;
  if (['AUTH_REQUIRED', 'INVALID_TOKEN', 'INVALID_REFRESH_TOKEN'].includes(message)) return 401;
  if (['FORBIDDEN', 'ACCOUNT_DELETED', 'DEMO_LOGIN_DISABLED'].includes(message)) return 403;
  if (message === 'NOT_FOUND' || message.endsWith('_NOT_FOUND') || message === 'MEDIA_NOT_FOUND' || message === 'IDENTIFY_NOT_FOUND') return 404;
  if (['AUTH_RATE_LIMITED', 'QUOTA_EXCEEDED', 'RATE_LIMITED'].includes(message)) return 429;
  if (message === 'EMAIL_NOT_CONFIGURED' || message === 'PROVIDER_UNAVAILABLE' || message.endsWith('_DEPENDENCY_UNAVAILABLE')) return 503;
  if (message === 'CONFLICT') return 409;
  if (message.startsWith('MISSING_') || message.startsWith('INVALID_') || message === 'MEDIA_REQUIRED' || message === 'AUTH_CODE_EXPIRED' || message === 'AUTH_CODE_LOCKED') return 400;
  return 500;
}

export function errorCategory(message, status = errorStatus(message)) {
  if (status === 401 || status === 403) return 'auth';
  if (status === 404) return 'not_found';
  if (status === 409) return 'conflict';
  if (status === 429) return 'rate_limit';
  if (status === 503 || message === 'PROVIDER_UNAVAILABLE') return 'provider';
  if (status >= 400 && status < 500) return 'validation';
  return 'internal';
}

const routePatterns = [
  [/^\/api\/posts\/[^/]+\/(like|favorite)$/, '/api/posts/:postId/$1'],
  [/^\/api\/posts\/[^/]+\/comments$/, '/api/posts/:postId/comments'],
  [/^\/api\/posts\/[^/]+\/report$/, '/api/posts/:postId/report'],
  [/^\/api\/posts\/[^/]+$/, '/api/posts/:postId'],
  [/^\/api\/users\/[^/]+\/block$/, '/api/users/:userId/block'],
  [/^\/api\/observations\/[^/]+$/, '/api/observations/:observationId'],
  [/^\/api\/media\/[^/]+$/, '/api/media/:mediaId'],
  [/^\/api\/identify\/[^/]+\/(confirm|feedback)$/, '/api/identify/:requestId/$1'],
  [/^\/media\/[^/]+$/, '/media/:fileName']
];

export function routeTemplate(pathname) {
  for (const [pattern, template] of routePatterns) {
    const match = pathname.match(pattern);
    if (match) return template.replace('$1', match[1] || '');
  }
  return pathname;
}
