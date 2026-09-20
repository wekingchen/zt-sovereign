# Security notes

- 不要提交 `.env`、`data/`、备份包、`identity.secret`、World signing keys、Controller `authtoken.secret`、ztncui 密码文件或 session secret。
- ztncui 默认只绑定宿主机 `127.0.0.1:3000`；远程管理建议通过 VPN、反向代理或 SSH tunnel。
- v0.4.0 首次启动默认生成随机一次性 admin 密码，而不是使用上游默认 `admin/password`。
- 一次性密码存放在 `/data/ztncui/initial-admin-password`，权限为 0600；首次改密成功后会删除。
- 如果设置 `ZTNCUI_ADMIN_PASSWORD`，请使用强随机密码并避免把它提交到仓库。
- PLANET 文件服务默认只绑定宿主机 `127.0.0.1:3001`，并使用持久化随机 key。
- Controller HTTP API 不映射到宿主机，仅供同容器 ztncui 访问。
- PLANET identity、World signing keys 与 Controller identity 是长期信任根；不要通过删除后重建来处理普通故障。
- `stable` 只是可移动的晋升指针；生产部署建议锁定具体 release tag。
- Upstream Check 会把 ZeroTier release tag 解析为 commit SHA；已固定 tag 若发生 retag，会失败并要求人工检查。
- Controller 不做自动跨兼容版本升级。
- `ztmkworld` 只从固定不可变 commit 获取；其来源与混合许可证边界记录在 `THIRD_PARTY_NOTICES.md`。
- 建议为 GitHub `production` Environment 配置 required reviewers，再允许 Promote Stable。
