# Web 与云端第三方软件清单

状态：比赛源码依赖初步清单。正式提交前由成员 C 依据锁文件与上游仓库再次核验版本、版权声明和许可证全文。

| 组件 | 当前用途 | 许可证 | 来源 |
|---|---|---|---|
| React / React DOM | Web UI | MIT | https://github.com/facebook/react |
| React Router | Web 路由 | MIT | https://github.com/remix-run/react-router |
| TanStack Query | API 查询与缓存状态 | MIT | https://github.com/TanStack/query |
| Apache ECharts | 观察统计可视化 | Apache-2.0 | https://github.com/apache/echarts |
| Vite | Web 构建 | MIT | https://github.com/vitejs/vite |
| TypeScript | 类型检查 | Apache-2.0 | https://github.com/microsoft/TypeScript |
| Vitest | Web 单元测试 | MIT | https://github.com/vitest-dev/vitest |
| Playwright | 浏览器 E2E | Apache-2.0 | https://github.com/microsoft/playwright |
| node-postgres (`pg`) | PostgreSQL 连接 | MIT | https://github.com/brianc/node-postgres |
| node-redis (`redis`) | DCS Redis 连接 | MIT | https://github.com/redis/node-redis |
| Huawei OBS Node.js SDK | 私有对象存储 | 以依赖包内许可证为准 | https://www.npmjs.com/package/esdk-obs-nodejs |
| Caddy | 比赛临时 HTTPS 入口 | Apache-2.0 | https://github.com/caddyserver/caddy |

## 发布动作

- [ ] 从 `web/package-lock.json` 与 `server/package-lock.json` 生成完整传递依赖清单。
- [ ] 保留所有 Apache-2.0 `NOTICE` 要求和第三方版权声明。
- [ ] 在 Web `/about`、HarmonyOS 许可证页和 GitHub README 提供一致的归属入口。
- [ ] 不把华为云、腾讯地图、GBIF、OpenMoji 或字体素材描述为团队原创。
