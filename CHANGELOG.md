# Changelog

## v0.5.0

- 将项目维护的 ztncui 默认界面完整切换为简体中文（`zh-CN`）。
- 汉化首页、导航、登录、管理员、网络、成员、路由、DNS、IP 分配、访问控制与 IPv4/IPv6 分配模式页面。
- 汉化后端生成的页面标题、表单校验、认证提示及用户可见错误信息。
- 新增 `ui/ztncui/src/locales/zh-cn.js`，为网络/成员详情中的常见 ZeroTier API 字段提供中文显示名称，同时保持底层 API 字段不变。
- 错误详情不再把第三方英文异常原文直接显示到页面；完整技术错误写入容器日志。
- 中文界面优先使用苹方、微软雅黑、Noto Sans CJK SC 等系统字体。
- 新增 `test_ztncui_zh_cn.py` 汉化回归检查，防止常见英文 UI 文案重新混入。
- ZeroTier 单二进制双实例、Controller API、持久化结构和 ztncui 数据格式均保持不变。


## v0.4.2

- 将 PLANET 与 Controller 的两个 ZeroTier 构建阶段收敛为一个共享 `zerotier_builder`。
- 只编译、存储一份 `ZeroTier 1.16.2 + ZT_NONFREE=1` 二进制，运行时启动 PLANET 与 Controller 两个独立进程。
- 两个进程继续使用独立端口、identity、home 和持久化目录，不合并信任身份。
- 版本 pin 收敛为 `ZEROTIER_VERSION` 与 `ZEROTIER_SOURCE_REF`，Upstream Check 只维护一套 ZeroTier 候选。
- 删除运行镜像中重复的 `/opt/zerotier-planet` / `/opt/zerotier-controller`，统一为 `/opt/zerotier`。
- 保持 ZeroTier Controller source-available 许可文本与个人非商业研究用途边界。


## v0.4.1

- Standalone Controller 从 ZeroTier 1.14.2 升级到 1.16.2，与 PLANET 使用同一正式版本基线。
- Controller 构建启用 `ZT_NONFREE=1`，恢复 1.16.2 中位于 `nonfree/controller` 的 FileDB Controller API。
- 真实集成测试确认 ztncui 0.8.14 可在 ZeroTier 1.16.2 上创建、列出、读取和删除 Network，并通过重启持久化测试。
- 项目用途明确调整为个人、非商业研究与学习；增加根目录 Personal Non-Commercial Research License，并保留 ZeroTier Controller source-available 许可文本。
- Upgrade Test 修复为使用 base 分支自己的 `scripts/build-local.sh`，移除已退役的 ZTNet 构建参数。
- Upstream Check 改为同时提出 PLANET 与 Controller 的最新 ZeroTier 正式版本候选，但仍必须通过 CI 后人工合并。


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
