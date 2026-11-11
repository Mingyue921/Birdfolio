# Birdfolio Beta 服务

开发环境继续使用 Node.js + SQLite；生产适配层支持 PostgreSQL、华为云 OBS、邮件网关和 HTTPS 入口。仓库只提供可部署工程与配置示例，不会创建或购买云资源。

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
GET http://127.0.0.1:8787/health/live
GET http://127.0.0.1:8787/health/ready
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

正式预检还要求 PostgreSQL、私有 OBS、邮件服务、`DEMO_MODE=false` 与 `HTTPS_PROXY=true`，任一配置缺失都会拒绝 Release 启动。完整拓扑与本地 PostgreSQL Compose 使用方法见 `infra/README.md`。

比赛环境使用 `DEPLOYMENT_PROFILE=competition`、`COMPETITION_DEMO_LOGIN=true`、`CACHE_PROVIDER=redis` 和私网 `REDIS_URL`。此模式开放 `POST /api/auth/demo-session`，为每位体验者创建隔离的 24 小时账号及两条明确标注的种子观察；商业环境若启用该开关会被发布预检拒绝。DCS Redis 用于原子限流与 10 分钟 AI 候选缓存，不缓存图片、Token 或精确位置。

## API 概览

当前服务提供：

```text
GET  /api/health
POST /api/auth/request-code
POST /api/auth/verify-code
POST /api/auth/refresh
POST /api/auth/logout
POST /api/auth/demo-session (competition profile only)
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
npm run db:migrate
npm run db:backup
npm run cleanup:demo
```

运行时数据位于 `data/`：SQLite 数据库、WAL 文件、上传图片和 GBIF 缓存均被忽略。数据库结构由 `src/migrations.mjs` 中的编号迁移管理；服务启动时自动执行尚未应用的迁移。未被帖子引用的过期上传会在启动时和 `MEDIA_CLEANUP_INTERVAL_MS` 周期内清理，上传有效期由 `MEDIA_TTL_MS` 控制。服务日志为单行 JSON，包含请求 ID、状态码和耗时，便于日志采集系统解析。正式部署至少需要定期备份数据库、配置 HTTPS/CORS、认证和请求限流；本地服务不应直接暴露到公网。

也可以在不启动 HTTP 服务的情况下执行一次媒体清理。命令读取 `server/.env`，使用 `DATABASE_PATH`（默认 `data/birdfolio.db`），并只输出扫描、删除和跳过数量：

```powershell
npm run cleanup:media
```

恢复是破坏性操作，只能在应用停止写入且已验证备份后执行；命令必须同时提供 `CONFIRM_RESTORE=RESTORE_BIRDFOLIO` 与 `--from=<备份文件>`：

```powershell
npm run db:restore -- --from=C:\protected-backups\birdfolio.dump
```

## 密钥和许可证

- `server/.env` 永远不要提交到仓库或发送到聊天/截图。
- AI Key 只存在服务端；客户端只调用服务端识鸟接口。
- 腾讯地图 Key 属于客户端受限凭据，应按包名、签名、来源和额度配置，并在公开前轮换。
- 图片、GBIF、OpenMoji、字体和 Fabric.js 的作者及许可证见根目录 `THIRD_PARTY_ASSETS.md`。
