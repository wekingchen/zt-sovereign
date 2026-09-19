# Security notes

- 不要提交 `.env`、`data/`、备份包、`identity.secret`、World signing keys、Controller `authtoken.secret` 或 PostgreSQL 数据。
- ZTNet 默认只绑定宿主机 `127.0.0.1:3000`。
- PLANET 文件服务默认只绑定宿主机 `127.0.0.1:3001`，且要求持久化 key。
- Controller HTTP API 不映射到宿主机，仅供同容器 ZTNet 使用。
- `stable` 只是晋升指针；生产部署建议锁定具体 release tag。
- Upstream Check 会把 release tag 解析为 commit SHA；已固定的 tag 若发生 retag，将触发失败而不是自动接受。
- 建议为 GitHub `production` Environment 配置 required reviewers，再允许 Promote Stable。
