# Third-party notices

本项目在构建或运行过程中使用第三方软件。使用、修改或分发镜像前，应同时遵守这些项目及实际固定版本所附的许可证。本文件用于记录工程来源与边界，不替代各上游许可证正文，也不构成法律意见。

## ZeroTierOne

Source: https://github.com/zerotier/ZeroTierOne

本项目有意将两个 ZeroTier 版本作为不同构建阶段和不同运行二进制处理：

- PLANET：跟踪经过 CI 验证的现代正式版本，使用不启用 `ZT_NONFREE` / Controller 的构建。
- Standalone Controller：保持在项目验证过的兼容版本；自动更新不会把它跨版本升级。

ZeroTier 的不同版本、组件和时间点可能适用不同许可。仓库自动化不会把“PLANET 可升级”推导成“Controller 也可按相同规则升级”。

## ztncui

Source: https://github.com/key-networks/ztncui

本项目已将 ztncui 固定源码导入 `ui/ztncui/` 并直接维护：

- Imported commit: `1b2284864de48d2dcae22582fff122fe24909c3d`
- Upstream version: `0.8.14`
- Upstream license: GNU GPL v3
- Provenance: `ui/ztncui/UPSTREAM.md`
- License copy: `ui/ztncui/LICENSE`

导入后的项目修改也保存在本仓库中，因此运行镜像不需要在构建时再下载 ztncui 源码。

## ztmkworld build helper

Source repository: https://github.com/sinamics/ztnet

ZeroTier Sovereign **不再运行或分发 ZTNet Web 应用本身**。当前只从 `versions.env` 中固定的不可变 commit `MKWORLD_SOURCE_REF` 取得 `ztnodeid/build/<arch>/ztmkworld`，作为生成自定义 PLANET world 的辅助程序。

当前固定来源：

- Source commit: `3ba175a682d03edd72516d830667ee08fe3cf262`
- Source subtree: `ztnodeid/`
- Runtime provenance: 镜像内 `/usr/local/share/zerotier-sovereign/mkworld-source-commit`

需要注意，固定的 `ztnodeid` 源码树并非可以简单概括成单一许可证：上游仓库根许可证为 GPLv3，而该子树中可见部分文件明确标记为 `AGPL-3.0-only`，另有来自 ZeroTier 的 BSD 3-Clause 许可代码。分发 `ztmkworld` 二进制时，应以固定 commit 中对应文件的实际版权/许可证声明为准，并保持对应源码可获得。

这里保留 ZTNet 仓库仅作为这个构建期 helper 的来源与可追溯入口；它不是 v0.4.0 的运行时管理界面、数据库层或应用依赖。

## Alpine Linux / Node.js / Rust / npm dependencies

v0.4.0 运行镜像基于 Alpine 版 Node.js。构建 ZeroTier 时使用 Alpine 工具链与 Rust；构建项目维护的 ztncui 时安装其 npm 运行依赖。这些软件与依赖分别遵守各自上游许可证。

## 已移除的 v0.3 运行组件

v0.4.0 不再包含 ZTNet、Next.js、Prisma 或 PostgreSQL 运行组件。旧版本中的 PostgreSQL 数据不会被新架构继续消费；升级时 PLANET、Controller 和 ztncui 的持久化状态与数据库退役是有意区分的。
