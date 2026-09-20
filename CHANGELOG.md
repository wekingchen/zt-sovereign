# Changelog

## v0.4.0

- 将运行架构收敛为单个 `zerotier-sovereign` 容器：PLANET + Standalone Controller + 项目维护的 ztncui。
- 移除 ZTNet、Next.js、Prisma 与 PostgreSQL 运行组件。
- 基础运行镜像切换到 `node:24-alpine3.24`；ztncui-only amd64 验证基线约 217 MiB（未压缩）。
- 将 ztncui 固定源码导入 `ui/ztncui/`，后续直接在本仓库维护；保留上游 commit、版本与 GPLv3 来源记录。
- ztncui 升级到 Node.js 24 可运行依赖，并保持真实 Controller API 集成测试。
- 首次启动不再使用上游默认 `admin/password`：默认生成随机一次性管理员密码，首次登录强制改密，并在改密后删除 bootstrap 密码文件。
- 新增 `sovereignctl ztncui-initial-password`。
- ztncui 凭据、session 与状态持久化到 `data/ztncui/`。
- Controller HTTP API 继续保持容器内 loopback，仅供同容器 ztncui 使用。
- Upgrade Test 改为通过 Docker daemon 迁移 root-owned 0600 状态文件，避免 CI 宿主权限误判。
- v0.3 -> v0.4 架构迁移明确保留 PLANET identity、World signing keys、Controller identity/network 数据及 ztncui 状态；PostgreSQL/ZTNet 数据有意退役。
- 构建时仅保留固定 commit 的 `ztmkworld` helper 来源，不再把 ZTNet 当运行时上游。
- Upstream Check 只自动跟踪 PLANET 的 ZeroTier 正式版本；Controller 仍按兼容分支人工控制。
- Candidate / Release 保持 GitHub 原生 amd64 + ARM64 Runner，并在 ARM64 上执行真实集成与重启持久化测试。
- 清理遗留 `run-ztnet` 运行入口及旧 `ZTNET_*` / `POSTGRES_*` 发布变量。

## v0.3.0

- 将 PLANET、Standalone Controller、ZTNet 合并为一个 `zerotier-sovereign` 业务镜像。
- PostgreSQL 保持独立容器。
- PLANET 与 Controller 仍使用独立 ZeroTier 二进制、identity 和工作目录。
- Controller API 改为容器内部 loopback 使用，不再通过 Docker bridge 暴露给 ZTNet。
- 新增 Supervisor 进程管理与统一 healthcheck。
- 新增 `sovereignctl version/status/health`。
- 增加 immutable source ref 支持与自动 Upstream Check。
- 新增真实 Controller API CRUD、重启持久化与 Upgrade Test。
- Candidate / Release 改用 GitHub 原生 x64 + ARM64 Runner。
