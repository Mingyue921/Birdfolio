# Birdfolio 观鸟手账

Birdfolio 是面向个人观鸟和自然教育活动的 HarmonyOS 原生应用。它把“识鸟候选、用户确认、观察记录、地图足迹、统计回顾和手账创作”放在一条可离线工作的流程中。

当前目标是可控的商业 Beta，而不是宣称已经完成大规模商业上线：数据默认保存在本机，用户主动开启同步后才上传；AI 只返回候选，必须由用户确认后才生成观察记录。

## Huawei ICT competition demo

`web/` contains the responsive Birdfolio Cloud competition experience. It reuses the same authenticated media, identification, confirmation and observation APIs as the HarmonyOS client; it does not fabricate AI candidates when the provider is unavailable.

```powershell
npm --prefix server ci
npm --prefix server test
npm --prefix web ci
npm --prefix web test
npm --prefix web run build
npm --prefix web run test:e2e
```

The target competition topology is ECS + RDS PostgreSQL + DCS Redis + private OBS + Huawei Cloud MaaS. Deployment examples live in `infra/`, while the API contract, acceptance checklist, three-minute script and truthful CodeArts evidence template live in `docs/competition/`. Cloud resources, CodeArts screenshots, MaaS credentials and the public HTTPS URL must be created and recorded by the team; the repository intentionally contains no credentials or fabricated evidence.

## 当前能力

| 模块 | 当前状态 |
| --- | --- |
| 观察记录 | 已支持照片、地点、数量、备注、单次定位和 Preferences 本地保存 |
| 地图与统计 | 腾讯地图 HarmonyOS SDK；鉴权/初始化失败时静态地图降级；统计按本地记录实时计算 |
| 鸟类图鉴 | 离线中文目录；可选 GBIF 补充，保留图片作者、许可和来源 |
| 手账 | ArkWeb + Fabric.js 本地编辑，支持文字、图片、贴纸和画笔草稿 |
| 社区 | 认证后的帖子、评论、点赞、收藏、分页、举报和屏蔽基础接口；管理员审核仍待上线 |
| AI 识鸟 | OpenAI-compatible 视觉服务适配器；返回 Top 3 候选，服务不可用时明确降级到离线图鉴 |
| 账号与云同步 | 邮箱验证码、Token、媒体授权和观察 push/pull 基础已接入；默认本地优先 |

支付、音频识鸟、PDF/整本手账导出和公网部署不属于当前交付范围，不在界面中伪造为已完成能力。真实邮件网关和 HTTPS 反向代理仍需在公开 Beta 前配置。

## 技术栈

- 客户端：HarmonyOS、ArkTS、ArkUI、NetworkKit、MediaLibraryKit、`geoLocationManager`、Preferences。
- 地图：腾讯地图 HarmonyOS SDK（`@tencentmap/map`、`@tencentmap/base`），保留静态降级。
- 手账：ArkWeb 内置本地 HTML/JavaScript 编辑器和 Fabric.js 5.3.0。
- Web：React、TypeScript、Vite、React Router、TanStack Query、ECharts、Vitest、Playwright。
- 后端：Node.js 22.5+（开发机为 Node.js 24）、原生 `node:http`、SQLite/PostgreSQL、Redis/DCS、REST API。
- AI：服务端 OpenAI-compatible Huawei MaaS 视觉适配器；不在客户端保存模型 Key，也不宣称自研训练模型。

## 本地开发

### 启动后端

```powershell
cd C:\Users\huawei\DevEcoStudioProjects\Birdfolio\server
npm ci
Copy-Item .env.example .env
# 编辑 .env；真实 VISION_API_KEY 只放在服务端
npm run check:env
npm start
```

健康检查：`http://127.0.0.1:8787/api/health`。开发环境未配置完整视觉模型时，检查命令会给出降级警告，识鸟接口不会伪造候选。

真机通过 Wi-Fi 访问时，把应用设置中的后端地址改为电脑 WLAN IPv4 地址；USB 调试可使用：

```powershell
hdc -t <设备序列号> rport tcp:8787 tcp:8787
```

然后在应用中使用 `http://127.0.0.1:8787`。反向转发只在 HDC 连接保持期间有效。

### 后端测试与发布预检

```powershell
npm --prefix server run test:ci
node scripts/check-release.mjs
```

`server/.env` 中的 `VISION_API_URL`、`VISION_API_KEY`、`VISION_MODEL` 必须全部填写才会进入 provider 模式。Release 检查使用：

```powershell
npm --prefix server run check:release
```

该命令不会打印密钥；Release 环境还要求 `NODE_ENV=production`、视觉端点使用 HTTPS、`REQUIRE_AUTH=true` 和明确的 `CORS_ORIGIN` allow-list。正式启动使用 `npm --prefix server run start:release`，服务会拒绝开发用 `0.0.0.0` 公网监听并要求 HTTPS 反向代理、邮件网关和完整视觉模型配置；不能直接把开发端口暴露到公网。

`.github/workflows/ci.yml` 在无 DevEco SDK 的 CI 环境中运行后端测试、环境契约检查和 Release 静态预检；签名 HAP 仍需在受保护的 DevEco/CI 构建机上生成。

### HarmonyOS 构建

1. 使用 DevEco Studio 打开项目并完成 Sync。
2. 选择 ARM64 真机或相同 ABI 的设备；腾讯地图原生库不适合 x86_64 模拟器验收。
3. 执行 `assembleHap`，确认构建日志为 `BUILD SUCCESSFUL`。
4. `node scripts/check-release.mjs` 会检查版本号、Release ArkTS 混淆、后端锁文件和必要的本地密钥入口。

当前 Release 混淆规则位于 `entry/obfuscation-rules.txt`，开关已启用。签名证书、`.p12`、`.p7b` 和密码必须由 DevEco 本机配置或 CI Secret 管理，不能提交到仓库；现有本机 `build-profile.json5` 不应直接复制到公开仓库。

## 隐私与数据边界

- 未登录用户可以离线记录、查图鉴、查看地图和制作手账。
- 上传照片进行 AI 识别前应取得用户授权；低置信度结果只作为候选，不自动写入记录。
- 观察记录默认保存在 Preferences；同步开启后才写入后端，精确坐标不应出现在日志中。
- `server/.env`、地图 Key、SQLite 数据库、上传图片和本地签名材料均被 `.gitignore` 保护。
- 发布前必须轮换曾经暴露的地图/签名凭据，并为地图 Key 配置包名、签名、来源和额度限制。

## 许可证与素材归属

第三方图片、贴纸、字体和 Fabric.js 的来源及许可证见 [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)。发布包必须保留 CC BY/CC BY-SA 的作者和许可说明；不应把 GBIF 或 OpenMoji 素材包装成自有原创内容。

## 目录速览

- `entry/src/main/ets/pages/Index.ets`：应用壳和页面路由。
- `entry/src/main/ets/services/`：观察、地图、定位、本地存储等服务。
- `entry/src/main/resources/rawfile/journal_editor/`：手账编辑器、字体和贴纸资源。
- `server/src/`：本地 REST 服务与数据层。
- `server/test/`：服务端回归测试。
- `DELIVERY.md`：演示、验收和发布门槛。
