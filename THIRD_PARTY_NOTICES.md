# Third-party notices

本项目在构建或运行过程中使用第三方软件。使用、修改或分发镜像前，应同时遵守这些项目各自版本所附的许可证。

## ZeroTierOne

Source: https://github.com/zerotier/ZeroTierOne

本项目有意将两个 ZeroTier 版本作为不同构建阶段和不同运行二进制处理：

- PLANET：跟踪经过 CI 验证的现代 release，使用不启用 `ZT_NONFREE` / Controller 的构建。
- Standalone Controller：当前保持在项目验证过的兼容版本，且不会由自动更新 workflow 跨版本升级。

ZeroTier 的不同版本、组件和时间点可能适用不同许可。仓库自动化不会把“PLANET 可升级”推导成“Controller 也可按相同规则升级”。

## ZTNet

Source: https://github.com/sinamics/ztnet

ZTNet repository declares GPL-3.0 licensing. 本项目从固定 release/commit 源码构建 ZTNet，并记录实际 source commit。

## PostgreSQL

Source: https://www.postgresql.org/

PostgreSQL 使用独立官方容器镜像，不被复制进 `zerotier-sovereign` 业务镜像。

## Debian / Node.js / Rust / npm dependencies

镜像构建还会使用 Debian、Node.js、Rust toolchain 及 ZTNet package-lock 中的 npm 依赖。它们各自遵守对应上游许可证。

本文仅用于说明工程边界，不构成法律意见。
