# Birdfolio Beta 交付与验收说明

本文是当前版本的事实清单和演示边界。它不把开发环境能力包装成商业上线能力。

## 交付定位

- 平台：HarmonyOS，优先使用 ARM64 真机验收。
- 用户：个人观鸟用户、校园自然观察和自然教育活动。
- 数据：本地优先；网络不可用时观察、图鉴、统计和手账仍可使用。
- AI：服务端统一配置视觉模型，客户端只提交获得授权的压缩图片；返回候选，用户确认后才写入观察记录。
- 商业状态：Beta 阶段免费，不接支付；账号、媒体授权、观察同步和社区治理基础已实现，公网运维和管理员审核仍需单独部署。

## 可演示主流程

1. 启动后端，确认 `/api/health` 返回 `service=birdfolio`。
2. 应用从相册选择鸟类照片，阅读并同意 AI 上传授权。
3. 查看最多三个候选及辨识依据，手动确认一个候选。
4. 补充数量、地点、备注；可按需获取一次当前位置并保存观察。
5. 在地图查看真实坐标 Marker；没有坐标的记录只出现在地点列表，不创建虚假 Marker。
6. 在年度统计查看当前记录的实时汇总。
7. 进入手账添加照片、字体、贴纸和画笔，确认草稿重启后仍在。
8. 进入社区验证帖子、评论、点赞和收藏；后端关闭时确认本地观察仍可保存。

## 后端启动

```powershell
cd C:\Users\huawei\DevEcoStudioProjects\Birdfolio\server
npm ci
Copy-Item .env.example .env
# 只在 server/.env 填写 VISION_API_URL、VISION_API_KEY、VISION_MODEL
npm run check:env
npm run test:ci
npm start
```

正式环境先将 `.env` 配置为 `NODE_ENV=production`、HTTPS 邮件/视觉端点、明确 `CORS_ORIGIN` 和 `REQUIRE_AUTH=true`，再运行 `npm run start:release`。Release 启动会拒绝开发用 `0.0.0.0` 监听和不完整的密钥配置。

真机 Wi-Fi 模式使用电脑 WLAN IPv4 地址；USB 调试模式使用：

```powershell
hdc -t <设备序列号> rport tcp:8787 tcp:8787
```

在手机浏览器先打开 `http://电脑IPv4地址:8787/api/health`。无法访问时检查 Windows 防火墙、校园网客户端隔离和后端终端是否仍在运行。

## 验收命令

```powershell
npm --prefix server run test:ci
node scripts/check-release.mjs
```

DevEco Studio 中执行 `assembleHap`，要求 `BUILD SUCCESSFUL`；安装包必须与真机 ABI 匹配。发布前还要核对：

- `AppScope/app.json5` 的 `versionName` 和 `versionCode` 已更新。
- `entry/build-profile.json5` 的 Release ArkTS 混淆已启用。
- 签名证书、`.p12`、`.p7b` 和密码只存在 DevEco 本机或 CI Secret，不进入仓库。
- `MapSecret.ets`、`server/.env`、数据库和上传文件没有被打包进源码提交。
- 真实地图 Key 已按包名、签名、来源和额度限制，发布前已轮换曾经暴露的凭据。
- 后端正式部署使用 HTTPS 反向代理、`REQUIRE_AUTH=true`、明确 `CORS_ORIGIN` allow-list、认证和限流；开发端口 `8787` 不能直接公网开放。

`.github/workflows/ci.yml` 只负责无 DevEco 依赖的后端和静态检查；签名 HAP 不在公开 CI 中生成，避免泄露证书和密码。

## 当前边界

以下能力不能作为“已完成商业能力”对外承诺：

- 邮箱登录、账号删除、数据导出和观察 push/pull 已提供基础接口；真实邮件网关、完整冲突解决 UI 和大规模跨设备验证仍需在公开 Beta 前完成。
- 手账整本 PNG/PDF 导出、音频识鸟、支付和素材商店支付。
- 社区身份隔离、举报、屏蔽及“所有人/仅自己”可见范围已实现基础版本；关注关系和管理员审核后台仍未开放。
- AI 的医学/科研级准确率或自研模型训练成果。当前只提供可替换的视觉服务适配器和用户确认机制。

若后端、AI 或地图不可用，界面必须显示具体状态（离线、未配置、鉴权失败或服务错误），并保留本地记录流程；不得显示固定成功率、虚假的“已同步”或未发生的识别结论。

## 数据、隐私与素材

- AI 照片在授权前不得读取或上传；撤回授权后不再发起上传。
- 服务端日志不得记录 Token、AI Key、完整照片 URI 或用户精确位置。
- 观察记录以 Preferences 为本地主数据源；服务端数据和上传图片位于 `server/data/`，不应纳入版本库。
- 离线图鉴、GBIF 图片、OpenMoji 贴纸、字体和 Fabric.js 的作者及许可证见 `THIRD_PARTY_ASSETS.md`；CC BY/CC BY-SA 素材发布时必须保留归属。

## 故障处理

- `AI 暂不可用`：先看 `/api/health` 的 `aiMode`，再检查三项 `VISION_*` 是否同时填写；不要把 Key 填到客户端。
- `后端未连接`：用手机浏览器验证健康检查 URL；Wi-Fi 不通时使用 HDC `rport`。
- `地图白屏/静态降级`：检查隐私授权、ARM64 ABI、Key 限制和腾讯地图 SDK 日志；静态地图属于预期降级，不代表观察数据丢失。
- 构建失败：先运行 `node scripts/check-release.mjs`，确认 DevEco SDK、签名配置和真机 ABI；不要删除本地证书文件来“修复”构建。
