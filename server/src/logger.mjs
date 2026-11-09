const REDACTED = '[REDACTED]';

function normalizedKey(key) { return String(key).replace(/[^a-z0-9]/gi, '').toLowerCase(); }

function sensitiveKey(key) {
  const value = normalizedKey(key);
  return value.includes('authorization') || value.includes('cookie') || value.includes('token') ||
    value.includes('apikey') || value.includes('secret') || value.includes('password') ||
    value === 'code' || (value.endsWith('code') && !['errorcode', 'statuscode'].includes(value)) || value === 'otp' ||
    value.includes('imagebase64') || value.includes('dataurl') || value.includes('binary') || value.endsWith('body') ||
    value === 'latitude' || value === 'longitude' || value.includes('coordinates') || value.includes('exactlocation') ||
    value.includes('photouri') || value.includes('photourl') || value.includes('imageuri') || value.includes('imageurl') || value.includes('mediauri') ||
    value.includes('filepath') || value.includes('localpath') || value.includes('mediapath') || value.includes('uploadpath');
}

function absoluteLocalPath(value) {
  return typeof value === 'string' && (/^[a-z]:[\\/]/i.test(value) || /^\/(?:Users|home|var|tmp|etc)\//.test(value));
}

export function redactLogValue(value, seen = new WeakSet()) {
  if (absoluteLocalPath(value)) return REDACTED;
  if (value === null || typeof value !== 'object') return value;
  if (seen.has(value)) return '[CIRCULAR]';
  seen.add(value);
  if (Array.isArray(value)) return value.map(item => redactLogValue(item, seen));
  const result = {};
  for (const [key, item] of Object.entries(value)) {
    result[key] = sensitiveKey(key) ? REDACTED : redactLogValue(item, seen);
  }
  return result;
}

export function createLogger(output = console) {
  function write(level, event, fields = {}) {
    const record = redactLogValue({ timestamp: new Date().toISOString(), level, event, ...fields });
    const method = level === 'error' ? 'error' : level === 'warn' ? 'warn' : 'log';
    output[method](JSON.stringify(record));
  }

  return {
    info: (event, fields) => write('info', event, fields),
    warn: (event, fields) => write('warn', event, fields),
    error: (event, fields) => write('error', event, fields)
  };
}

export { REDACTED };
