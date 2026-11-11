# 华为云部署运行手册

状态：待人工执行。不得在本文填写真实密钥。

## 1. 资源开通

优先选择赛事允许且 MaaS 可用的同一区域：

- [ ] ECS 2 核 4 GB，绑定弹性公网 IP。
- [ ] RDS PostgreSQL 17；控制台不提供时选 16。
- [ ] DCS Redis 7 单实例。
- [ ] 私有 OBS 桶，禁止公共访问。
- [ ] MaaS 多模态模型访问权限与配额。
- [ ] CodeArts 项目、代码仓、流水线和部署环境。

记录资源 ID 时仅保存在团队密码管理器或受控台账，不提交账号、IP 白名单细节和凭据。

## 2. 网络

- Web/API：公网仅 443。
- SSH：22 仅团队固定出口 IP，部署稳定后尽量关闭或改为运维通道。
- RDS、DCS：仅 ECS 私网安全组可访问。
- OBS：私有桶；服务端 IAM 凭据最小权限。
- MaaS：只由服务端调用。

## 3. HTTPS 决策

1. 先检查赛事/APIG 是否提供托管 HTTPS 地址。
2. 若提供，使用大陆区域资源并通过托管入口代理 Web/API。
3. 若不提供，使用香港 ECS、`<公网IP>.sslip.io` 与 Caddy 自动证书。
4. `sslip.io` 仅用于比赛演示，商业发布仍需备案域名和正式证书。

## 4. Secret 与环境

在 CodeArts Secret 中配置，名称以服务端实际环境模板为准：

- PostgreSQL 连接信息
- Redis/DCS 连接信息
- OBS endpoint、bucket 与最小权限凭据
- `VISION_PROVIDER=huawei_maas`
- MaaS URL、Key、模型名
- Token 密钥
- `DEPLOYMENT_PROFILE=competition`
- `COMPETITION_DEMO_LOGIN=true`

禁止把 `.env`、导出的流水线 Secret、数据库备份或用户照片提交 Git。

## 5. 流水线

固定步骤：

1. 锁定依赖安装。
2. 服务端测试。
3. Web 单元测试。
4. Web 构建。
5. Docker 镜像构建并使用 commit SHA 标记。
6. Release/competition 配置预检。
7. 数据库迁移。
8. 部署新容器。
9. 请求 `/health/live` 和 `/health/ready`。
10. 失败则恢复上一镜像，并记录失败证据。

## 6. 首次发布验证

```text
GET https://<demo-host>/health/live
GET https://<demo-host>/health/ready
GET https://<demo-host>/api/health
```

随后从浏览器完成：快捷登录 → 上传 → Top 3 → 人工确认 → 观察出现 → 统计更新。

## 7. 回滚

1. 停止继续部署并保留失败容器日志。
2. 将流量切回上一 commit SHA 镜像。
3. 仅执行经过验证的向后兼容数据库回滚；不直接删除生产表。
4. 复查 live/ready 和核心流程。
5. 在 CodeArts 证据台账记录原因、修复和复核人。

## 8. 人工交付信息

- 公网演示 URL：`[待人工填写]`
- 部署区域：`[待人工填写]`
- 流水线链接：`[待人工填写，不公开 Secret]`
- 当前镜像 SHA：`[待人工填写]`
- 最近回滚演练：`[待人工填写]`
