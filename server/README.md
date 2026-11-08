# Birdfolio 本地 Beta 服务

这是 Birdfolio 的 Node.js + SQLite 服务端，供开发机和同一局域网的 HarmonyOS 真机演示使用。它不是公网生产部署方案：当前监听 HTTP 开发端口，正式上线前必须放在 HTTPS 反向代理后，并完成认证、限流、备份和内容治理。

## 要求

- Node.js `>=22.5.0`（使用内置 `node:sqlite`，不需要额外安装数据库）。
- Windows PowerShell 或等价终端。
- 真机联调时，电脑和设备处于可互访的同一网络，或保持 HDC USB 连接。

## 安装与启动

```powershell
cd C:\Users\huawei\DevEcoStudioProjects\Birdfolio\server
npm ci
Copy-Item .env.example .env
# 在 .env 中填写视觉服务配置（Key 只放服务端）
npm run check:env
npm start
```

启动脚本也可以使用 `start-server.ps1`。它会检查 Node 版本、避免重复占用 8787 端口并打印 WLAN 地址。开发环境可以不配置视觉模型，此时 `/api/health` 会返回 `aiMode: unavailable`，客户端应进入明确的离线/不可用状态。

健康检查：

```text
GET http://127.0.0.1:8787/api/health
```

## 环境变量

复制 `.env.example` 后配置：

```text
NODE_ENV=development
PORT=8787
HOST=0.0.0.0
VISION_API_URL=https://服务商的完整Chat-Completions地址
VISION_API_KEY=服务端密钥
VISION_MODEL=支持图片输入的模型名
# 本地兼容演示可设 false；正式部署必须 true
REQUIRE_AUTH=true
# 正式部署必填，不能使用 *
CORS_ORIGIN=https://your-app.example.com
# 邮箱验证码网关；没有网关时仅允许本地 AUTH_DEBUG_CODES=true 调试
MAIL_PROVIDER_URL=https://mail-gateway.example.com/send
MAIL_PROVIDER_TOKEN=受保护的服务端令牌
```

三项 `VISION_*` 必须全部填写才进入 provider 模式。`npm run check:release` 会额外要求视觉端点使用 HTTPS、`REQUIRE_AUTH=true` 和明确的 `CORS_ORIGIN`；它不会打印密钥。正式环境应由反向代理终止 TLS，并配置 `MAIL_PROVIDER_URL` 投递验证码；没有邮件网关时服务会明确返回不可用，不会假装验证码已发送。`AI_DAILY_LIMIT` 默认 10 次/账号/24 小时；`AUTH_DEBUG_CODES` 和 `AUTH_DEV_CODE` 仅用于本地测试。

## API 概览

当前服务提供：

```text
GET  /api/health
POST /api/auth/request-code
POST /api/auth/verify-code
POST /api/auth/refresh
POST /api/auth/logout
GET  /api/me
POST /api/account/export
DELETE /api/account
GET  /api/posts
POST /api/posts
GET  /api/posts/:id
DELETE /api/posts/:id
POST /api/posts/:id/like
POST /api/posts/:id/favorite
GET  /api/posts/:id/comments
POST /api/posts/:id/comments
POST /api/posts/:id/report
POST /api/users/:id/block
GET  /api/observations
PUT  /api/observations/:id
POST /api/media
GET  /api/media/:id
POST /api/identify/image
POST /api/identify/:requestId/confirm
POST /api/identify/:requestId/feedback
POST /api/sync/push
GET  /api/sync/pull?cursor=...
POST /api/sync/resolve
GET  /api/species
```

服务端现在提供邮箱验证码会话、短期媒体、识别确认/反馈和 push/pull/resolve 同步基础接口；客户端仍以 Preferences 为本地主数据源，网络失败不能阻塞本地增删改。正式公开云端入口前，还需要接入真实邮件投递、HTTPS、认证限流、备份恢复和社区治理。

## 真机联调

Wi-Fi 模式：在手机浏览器先打开 `http://电脑WLANIPv4:8787/api/health`，再把同一地址写入应用设置。无法访问时检查 Windows 防火墙和路由器客户端隔离。

USB 调试模式：

```powershell
hdc -t <设备序列号> rport tcp:8787 tcp:8787
```

然后应用使用 `http://127.0.0.1:8787`。HDC 断开或设备重启后需要重新建立转发。

## 测试与发布预检

```powershell
npm run test
npm run test:ci
npm run check:env
npm run check:release
```

运行时数据位于 `data/`：SQLite 数据库、WAL 文件、上传图片和 GBIF 缓存均被忽略。正式部署至少需要定期备份数据库、限制上传大小和类型、移除图片 EXIF、配置 HTTPS/CORS、认证和请求限流；本地服务不应直接暴露到公网。

## 密钥和许可证

- `server/.env` 永远不要提交到仓库或发送到聊天/截图。
- AI Key 只存在服务端；客户端只调用服务端识鸟接口。
- 腾讯地图 Key 属于客户端受限凭据，应按包名、签名、来源和额度配置，并在公开前轮换。
- 图片、GBIF、OpenMoji、字体和 Fabric.js 的作者及许可证见根目录 `THIRD_PARTY_ASSETS.md`。
