import { existsSync, readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const errors = [];
const warnings = [];

function read(relativePath) {
  const absolutePath = resolve(root, relativePath);
  if (!existsSync(absolutePath)) {
    errors.push(`缺少 ${relativePath}`);
    return '';
  }
  return readFileSync(absolutePath, 'utf8');
}

const nodeMajor = Number(process.versions.node.split('.')[0]);
const nodeMinor = Number(process.versions.node.split('.')[1]);
if (nodeMajor < 22 || (nodeMajor === 22 && nodeMinor < 5)) {
  errors.push(`Node.js 需要 >= 22.5，当前为 ${process.version}`);
}

const appConfig = read('AppScope/app.json5');
const versionMatch = appConfig.match(/["']?versionName["']?\s*:\s*["']([^"']+)["']/);
const codeMatch = appConfig.match(/["']?versionCode["']?\s*:\s*(\d+)/);
if (!versionMatch || !versionMatch[1]) errors.push('AppScope/app.json5 缺少 versionName');
if (!codeMatch || Number(codeMatch[1]) <= 0) errors.push('AppScope/app.json5 缺少有效 versionCode');

const entryProfile = read('entry/build-profile.json5');
if (!/"enable"\s*:\s*true/.test(entryProfile)) {
  errors.push('Release ArkTS 混淆未启用');
}
const obfuscationRules = read('entry/obfuscation-rules.txt');
if (!existsSync(resolve(root, 'entry/obfuscation-rules.txt'))) {
  errors.push('缺少 entry/obfuscation-rules.txt');
} else {
  const webBridgeProperties = ['saveBook', 'requestCloseEditor', 'deleteBook', 'pickImage', 'readImage', 'exportImageChunk', 'finishExportImage', 'reportEditorEvent'];
  for (const property of webBridgeProperties) {
    if (!new RegExp(`(^|\\r?\\n)${property}(\\r?\\n|$)`).test(obfuscationRules)) {
      errors.push(`Release 混淆必须保留 WebView 桥接属性：${property}`);
    }
  }
}

const appProfile = read('build-profile.json5');
if (/"signingConfigs"\s*:\s*\[\s*\]/s.test(appProfile)) {
  warnings.push('当前 build-profile.json5 未配置签名；请在 DevEco Studio 本机或受保护 CI 中选择签名配置后再生成 HAP');
} else if (/"keyPassword"|"storePassword"|"certpath"|"storeFile"/.test(appProfile)) {
  warnings.push('build-profile.json5 含本机签名字段时只能作为本地文件使用；公开仓库/CI 应迁移到受保护凭据');
}

const packageLock = read('server/package-lock.json');
if (!/"lockfileVersion"\s*:\s*3/.test(packageLock)) errors.push('server/package-lock.json 不是 lockfileVersion 3');
const serverPackage = read('server/package.json');
if (!/"check:release"/.test(serverPackage)) errors.push('server 缺少 check:release 脚本');
const ignore = read('.gitignore');
if (!ignore.includes('/server/.env') && !ignore.includes('**/.env')) {
  warnings.push('请确认 .gitignore 忽略所有真实 .env 文件');
}
for (const requiredRule of ['/entry/src/main/ets/services/MapSecret.ets', '**/*.p12']) {
  if (!ignore.includes(requiredRule)) warnings.push(`请确认 .gitignore 保留规则：${requiredRule}`);
}

if (existsSync(resolve(root, 'entry/src/main/ets/services/MapSecret.ets'))) {
  console.log('MapSecret.ets: present (value hidden; keep local and rotate before public release)');
} else {
  warnings.push('未找到 MapSecret.ets；地图鉴权需在 DevEco 本地配置');
}
if (errors.length) {
  console.error('Birdfolio release preflight failed:');
  for (const error of errors) console.error(`- ${error}`);
  process.exitCode = 1;
} else {
  console.log('Birdfolio release preflight passed');
  console.log(`- app version: ${versionMatch?.[1] || 'unknown'} (${codeMatch?.[1] || 'unknown'})`);
  console.log('- release obfuscation: enabled');
  console.log('- server lockfile: present');
  for (const warning of warnings) console.warn(`! ${warning}`);
}
