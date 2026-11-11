# Web Demo API 契约

状态：进行中。现有接口按源码核验；标为“比赛新增”的接口需以后端测试通过为准。

## 通用约定

- Web 与 API 同源部署，生产路径统一以 `/api` 开头。
- 除健康检查、物种搜索、验证码和比赛快捷登录外，业务接口均使用 `Authorization: Bearer <accessToken>`。
- JSON 请求设置 `Content-Type: application/json`。
- 每个响应通过 `X-Request-Id` 或响应体中的 `requestId` 关联服务端日志。
- 客户端不得提交可信 `userId`；服务端从 Token 解析账号。
- 失败响应至少包含 `error`，可选 `message`、`requestId` 和 `details`。UI 不直接展示内部堆栈。

## 认证

### `POST /api/auth/demo-session`（比赛新增）

仅在 `DEPLOYMENT_PROFILE=competition` 且 `COMPETITION_DEMO_LOGIN=true` 开放。

成功 `200`：

```json
{
  "accessToken": "<redacted>",
  "refreshToken": "<redacted>",
  "expiresIn": 900,
  "accountExpiresAt": 1795526400000,
  "user": { "id": "demo-...", "displayName": "比赛体验用户" }
}
```

错误：`403 DEMO_LOGIN_DISABLED`、`429 RATE_LIMITED`、`503 DEPENDENCY_UNAVAILABLE`。

### 邮箱登录（现有）

- `POST /api/auth/request-code`：`{ "email": "..." }`
- `POST /api/auth/verify-code`：`{ "email": "...", "code": "..." }`
- `POST /api/auth/refresh`：`{ "refreshToken": "..." }`
- `POST /api/auth/logout`：Bearer Token + `{ "refreshToken": "..." }`
- `GET /api/me`：读取当前账号。

Web 比赛入口优先使用 demo-session；刷新失败必须清除本地会话并返回登录页。

## 媒体与识别

### `POST /api/media`（现有）

浏览器先将最长边压缩至 1600px、JPEG 质量 0.85，并通过重绘移除 EXIF。当前服务端接受 JSON Data URL：

```json
{
  "fileName": "bird.jpg",
  "mimeType": "image/jpeg",
  "dataUrl": "data:image/jpeg;base64,..."
}
```

成功 `201` 至少返回 `id`（Web 统一映射为 `mediaId`）。禁止在日志或证据文档记录 Data URL。

### `POST /api/identify/image`（现有，响应扩展）

```json
{
  "mediaId": "media-...",
  "observedAt": "2026-11-18T08:30:00.000Z",
  "placeName": "福州湿地",
  "regionCode": "CN-FJ",
  "habitat": "wetland"
}
```

成功 `200`：

```json
{
  "requestId": "identify-...",
  "mode": "provider",
  "provider": "huawei_maas",
  "modelVersion": "<configured-model>",
  "cacheHit": false,
  "elapsedMs": 2380,
  "warning": "请根据现场特征人工确认",
  "candidates": [
    {
      "speciesId": "egret",
      "commonName": "白鹭",
      "modelScore": 0.82,
      "contextScore": 0.76,
      "finalScore": 0.80,
      "reasons": ["白色体羽", "湿地环境匹配"]
    }
  ]
}
```

候选最多 3 个。`finalScore` 低于服务端阈值时 UI 必须明确标示低置信度且不得自动确认。

错误语义：

- `400 INVALID_MEDIA` / `NO_CANDIDATES`
- `401 UNAUTHORIZED`
- `429 QUOTA_EXCEEDED`
- `502 PROVIDER_ERROR`
- `503 UNAVAILABLE`
- `504 PROVIDER_TIMEOUT`

### `POST /api/identify/:requestId/confirm`（现有）

```json
{
  "speciesId": "egret",
  "observation": {
    "observedAt": "2026-11-18T08:30:00.000Z",
    "placeName": "福州湿地",
    "fuzzyLocation": true
  }
}
```

只有成功确认后才允许刷新观察记录与仪表盘。前端重复提交必须禁用按钮；服务端应保持幂等。

### `POST /api/identify/:requestId/feedback`（现有）

用于记录“候选不正确/手动改选”，不得包含不必要的照片或精确坐标。

## 观察与统计

- `GET /api/observations`：当前账号的观察数组。
- `PUT /api/observations/:observationId`：创建或更新观察，要求合法 `updatedAt`。
- `DELETE /api/observations/:observationId`：按冲突规则软删除。

Web 仪表盘本轮从观察数组在浏览器聚合：总观察数、去重鸟种数、日期趋势和模糊地区分布；不新增伪造统计接口。

## 辅助接口

- `GET /api/species?q=<query>&limit=<1..50>`：物种搜索。
- `GET /api/health`：应用状态与 AI 配置模式。
- `GET /health/live`：仅验证进程存活。
- `GET /health/ready`：比赛环境必须同时验证 RDS、Redis/DCS 和 OBS；任一必需依赖不可用返回 `503`。

## 契约变更流程

1. 提议者先修改本文并写明兼容策略。
2. 成员 A、B 同时确认后再实现。
3. 服务端增加契约测试，Web 增加 API 映射测试。
4. 11 月 16 日冻结后，只接受 P0/P1 兼容性修复。
