# Changelog

## v0.3.0

- 将 PLANET、Standalone Controller、ZTNet 合并为一个 `zerotier-sovereign` 业务镜像。
- PostgreSQL 保持独立容器。
- PLANET 与 Controller 仍使用独立 ZeroTier 二进制、identity 和工作目录。
- Controller API 改为容器内部 loopback 使用，不再通过 Docker bridge 暴露给 ZTNet。
- 新增 Supervisor 进程管理与统一 healthcheck。
- 新增 `sovereignctl version/status/health`。
- ZTNet 构建从 release lockfile 继承 Node/Prisma 依赖，不再在本项目单独写死 Prisma 版本。
- 增加 immutable source ref 支持：release tag 可解析并固定到 commit SHA。
- 新增每日 Upstream Check：自动检测 ZeroTier PLANET 与 ZTNet 正式 Release，提交候选升级 PR。
- Controller 兼容版本不做自动跨版本升级。
- 新增 CI：Shell/Python 静态检查、单元测试、真实 Controller API CRUD、重启持久化测试。
- 新增 Upgrade Test：base -> candidate 复用 PostgreSQL 与 ZeroTier 状态进行升级验证。
- Candidate / Release 改用 GitHub 原生 x64 + ARM64 Runner 并行构建，不再使用 QEMU 模拟 ARM64。
- BuildKit 缓存按架构长期保存；main CI、Candidate、Release 共享同一架构缓存，未变化的 ZeroTier / ZTNet 构建层可直接复用。
- PR 使用独立 amd64 cache scope，避免覆盖 main 的生产候选缓存。
- 新增多架构 candidate/release 发布流程与人工 `stable` 晋升。
- 生产部署建议锁定明确版本号，不直接追 `candidate` / `stable`。
