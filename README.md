<div align="center">
  <img src="AppScope/resources/base/media/foreground.png" width="96" alt="Birdfolio Logo">
  <h1>Birdfolio 观鸟手账</h1>
  <p>识别、记录、整理每一次与鸟类的相遇</p>
</div>

Birdfolio 是一套面向观鸟爱好者和自然教育活动的数字观鸟工具，由 HarmonyOS 客户端、响应式 Web 应用和 Node.js 服务端组成。

用户可以上传鸟类照片获取 AI 候选，结合时间、地点和栖息环境完成确认，再把结果保存为观察记录。记录会继续用于地图足迹、个人统计和观鸟手账，不需要在多个应用之间重复整理照片与信息。

## 使用流程

```text
拍摄或选择照片
       ↓
AI 返回 Top 3 候选和辨识依据
       ↓
结合地点、季节和栖息环境辅助排序
       ↓
用户确认鸟种
       ↓
生成观察记录 → 地图 / 统计 / 手账
```

AI 负责缩小范围，鸟种由用户最终确认。低置信度、没有候选或服务异常时，可以直接进入离线图鉴手动选择。

## 主要功能

### AI 辅助识鸟

- 从相册选择照片或拍照识别
- 返回最多三个候选鸟种
- 展示模型分数、环境分数、综合分数和辨识特征
- 结合观察时间、粗粒度地点和栖息环境重新排序
- 确认候选后生成观察记录

### 观察记录

- 保存鸟种、时间、地点、数量、行为、照片和文字备注
- 使用模糊定位保护敏感鸟类位置
- 本地保存观察记录，支持离线查看和编辑
- 通过同步队列与服务端交换更新

### 地图、统计与图鉴

- 使用腾讯地图展示个人观鸟足迹
- 统计观察次数、鸟种数量、时间趋势和地区分布
- 提供离线鸟类图鉴和中文搜索
- 可通过 GBIF 补充物种资料及图片来源

### 观鸟手账

- 使用文字、照片、贴纸和画笔制作多页手账
- 支持字体、颜色、图层、模板和页面管理
- 图片、贴纸和字体资源随应用保存
- 手账内容与观察记录关联

### 社区与账号

- 邮箱验证码登录
- 发布图文观察，支持评论、点赞、收藏、举报和屏蔽
- 游客可使用本地功能，登录后可选择云同步
- 个人数据按账号隔离

## 两个客户端

| 客户端 | 适用场景 | 主要能力 |
|---|---|---|
| HarmonyOS 应用 | 户外观察与日常记录 | 拍照、定位、地图、离线图鉴、统计、手账和社区 |
| Birdfolio Cloud Web | 浏览器体验与云端展示 | 图片识别、候选确认、观察列表、统计看板和技术说明 |

Web 页面位于 `web/`，与 HarmonyOS 客户端共用认证、媒体、识别和观察 API。

## 技术栈

| 部分 | 技术 |
|---|---|
| HarmonyOS 客户端 | ArkTS、ArkUI、NetworkKit、MediaLibraryKit、ArkData relationalStore |
| 地图 | 腾讯地图 HarmonyOS SDK |
| 手账编辑器 | ArkWeb、Fabric.js、HTML Canvas |
| Web | React、TypeScript、Vite、React Router、TanStack Query、ECharts |
| 服务端 | Node.js、原生 `node:http`、REST API |
| 数据库 | SQLite（本地开发）、PostgreSQL（云端） |
| 缓存与限流 | Redis / 华为云 DCS |
| 图片存储 | 本地文件、华为云 OBS |
| AI | 华为云 MaaS / OpenAI-compatible 多模态接口 |
| 部署 | Docker、Caddy、华为云 ECS、CodeArts |
| 测试 | Node.js Test Runner、Vitest、Testing Library、Playwright、Hypium |

## 项目结构

```text
Birdfolio/
├─ entry/                  HarmonyOS 应用源码与资源
│  └─ src/main/
│     ├─ ets/              页面、组件、服务、数据与媒体管理
│     └─ resources/        图鉴图片、字体、贴纸和手账编辑器
├─ web/                    React 响应式 Web 应用
├─ server/                 Node.js API、数据库迁移和测试
├─ infra/                  PostgreSQL、Docker 与 HTTPS 部署示例
├─ catalog/                鸟类目录相关数据
├─ docs/                   合规、架构和比赛文档
└─ scripts/                构建与发布检查脚本
```

## 本地运行

### 1. 启动服务端

需要 Node.js 22.5 或更高版本。

```powershell
cd server
npm ci
Copy-Item .env.example .env
npm run check:env
npm start
```

服务默认运行在 `http://127.0.0.1:8787`：

```text
GET /api/health
GET /health/live
GET /health/ready
```

若需要使用视觉模型，在 `server/.env` 中配置：

```dotenv
VISION_PROVIDER=huawei_maas
VISION_API_URL=https://example.com/v1/chat/completions
VISION_API_KEY=your-server-side-key
VISION_MODEL=vision-model-name
```

模型 Key 只由服务端读取，不应写入 HarmonyOS 或 Web 客户端。

### 2. 启动 Web

```powershell
cd web
npm ci
npm run dev
```

浏览器访问 `http://localhost:5173`。Vite 开发服务器会把 `/api` 请求转发到本机 8787 端口。

### 3. 运行 HarmonyOS 应用

1. 使用 DevEco Studio 打开仓库根目录并完成 Sync。
2. 在本机配置调试签名和腾讯地图 Key。
3. 连接 ARM64 HarmonyOS 真机。
4. 选择 `entry` 模块并点击 Run。

USB 联调后端时可以建立端口反向转发：

```powershell
hdc -t <设备序列号> rport tcp:8787 tcp:8787
```

然后在应用设置中使用 `http://127.0.0.1:8787`。

## 测试

```powershell
# 服务端
npm --prefix server test

# Web 单元测试与构建
npm --prefix web test
npm --prefix web run build

# Web 桌面端与移动端 E2E
npm --prefix web run test:e2e

# 发布配置检查
node scripts/check-release.mjs
npm --prefix server run check:release
```

PostgreSQL 集成测试通过 `TEST_DATABASE_URL` 连接独立测试库，并为每次测试创建临时 Schema。

## 部署

`infra/` 提供以下配置示例：

- PostgreSQL 本地集成测试环境
- ECS 上的 Node.js API 容器
- Caddy HTTPS 入口
- RDS PostgreSQL、DCS Redis、私有 OBS 和 MaaS 环境变量模板
- 数据库迁移、备份、恢复及媒体清理命令

详细步骤见 [infra/README.md](infra/README.md)。

## 文档

- [服务端接口与运行说明](server/README.md)
- [第三方图片、字体与贴纸来源](THIRD_PARTY_ASSETS.md)
- [隐私与用户协议草案](docs/legal/README.md)
- [Birdfolio Cloud API 契约](docs/competition/api-contract.md)
- [云端系统架构](docs/competition/architecture.md)

## 许可证

Birdfolio 源代码使用 [Apache License 2.0](LICENSE)。

项目中的字体、鸟类图片、OpenMoji 贴纸、地图 SDK 和其他第三方资源继续遵循各自的许可证与服务条款，具体归属见 [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md) 和 [第三方软件清单](docs/competition/third-party-software.md)。
