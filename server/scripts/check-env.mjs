import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const release = process.argv.includes('--release');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

function parseEnvFile(filePath) {
  if (!existsSync(filePath)) return {};
  const values = {};
  for (const rawLine of readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;
    const separator = line.indexOf('=');
    if (separator <= 0) continue;
    const key = line.slice(0, separator).trim();
    let value = line.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return values;
}

const values = { ...parseEnvFile(resolve(root, '.env')), ...process.env };
const errors = [];
const warnings = [];

const nodeMajor = Number(process.versions.node.split('.')[0]);
const nodeMinor = Number(process.versions.node.split('.')[1]);
if (nodeMajor < 22 || (nodeMajor === 22 && nodeMinor < 5)) {
  errors.push(`Node.js 需要 >= 22.5，当前为 ${process.version}`);
}

const port = Number(values.PORT || 8787);
if (!Number.isInteger(port) || port < 1 || port > 65535) errors.push('PORT 必须是 1-65535 的整数');
const host = String(values.HOST || '0.0.0.0').trim();
if (!host) errors.push('HOST 不能为空');
if (release && (host === '0.0.0.0' || host === '::')) errors.push('Release 环境不能直接监听 0.0.0.0/::，请使用本机回环地址并置于 HTTPS 反向代理后');

const visionKeys = ['VISION_API_URL', 'VISION_API_KEY', 'VISION_MODEL'];
const configuredVision = visionKeys.filter(key => String(values[key] || '').trim().length > 0);
if (configuredVision.length > 0 && configuredVision.length < visionKeys.length) {
  errors.push('VISION_API_URL、VISION_API_KEY、VISION_MODEL 必须同时配置，不能只填其中一部分');
}
if (configuredVision.length === 0) {
  if (release) errors.push('Release 环境必须配置视觉模型；开发环境可保留离线降级');
  else warnings.push('未配置视觉模型，识鸟将使用明确标注的离线/不可用降级');
}
if (configuredVision.length === visionKeys.length) {
  try {
    const endpoint = new URL(values.VISION_API_URL);
    if (release && endpoint.protocol !== 'https:') errors.push('Release 环境的 VISION_API_URL 必须使用 HTTPS');
    if (!['http:', 'https:'].includes(endpoint.protocol)) errors.push('VISION_API_URL 必须是 http(s) 地址');
  } catch {
    errors.push('VISION_API_URL 不是有效 URL');
  }
}

const cors = String(values.CORS_ORIGIN || values.CORS_ORIGINS || '').trim();
if (release && (!cors || cors === '*')) errors.push('Release 环境必须配置明确的 CORS_ORIGIN，禁止为空或使用 *');
if (release && String(values.REQUIRE_AUTH || '').toLowerCase() !== 'true') errors.push('Release 环境必须设置 REQUIRE_AUTH=true');
if (release && String(values.NODE_ENV || '').toLowerCase() !== 'production') {
  errors.push('Release 环境必须设置 NODE_ENV=production');
}

const envFile = resolve(root, '.env');
if (!existsSync(envFile)) warnings.push('未找到 server/.env；启动脚本会从 .env.example 创建开发配置');

if (errors.length > 0) {
  console.error(`Birdfolio server 环境检查失败（${release ? 'release' : 'development'}）：`);
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log(`Birdfolio server 环境检查通过（${release ? 'release' : 'development'}）`);
  console.log(`- Node.js: ${process.version}`);
  console.log(`- Listen: ${host}:${port}`);
  console.log(`- Vision: ${configuredVision.length === visionKeys.length ? 'provider configured' : 'offline fallback'}`);
  for (const warning of warnings) console.warn(`! ${warning}`);
}
