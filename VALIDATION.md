# Validation status — v0.5.0 candidate

v0.5.0 的发布判断以 GitHub Actions 的真实构建和运行结果为准，不以静态代码审查代替运行验证。

## 已建立的验证层

### 静态与单元测试

- ShellCheck
- Bash / Python / JavaScript syntax
- ztncui 简体中文界面回归检查（禁止常见英文 UI 文案重新出现）
- PLANET 初始化、ensure、regenerate
- identity / signing key 持久化
- World timestamp 单调递增
- signing key 缺失时拒绝继续
- PLANET 文件服务认证与目录穿越防护
- `versions.env` / `.env.example` 同步

### amd64 集成测试

CI 会在 GitHub 原生 amd64 Runner 上：

- 从固定源码 commit 只构建一份 ZeroTier 1.16.2 二进制，并启用 `ZT_NONFREE=1`；
- PLANET 与 Controller 两个启动器必须使用同一个 `/opt/zerotier/zerotier-one` 文件；
- 构建项目内维护的简体中文 ztncui；
- 启动完整单容器运行栈；
- 校验 PLANET 文件服务；
- 通过真实 Controller REST API 创建/读取/删除测试 Network；
- 通过 ztncui Controller client 创建、列出、读取、删除测试 Network；
- 验证 ztncui 首次随机密码、强制改密及 bootstrap 文件删除；
- 重启后检查 PLANET identity、World keys、Controller identity、Network 与 ztncui 状态。

### Upgrade Test

PR 会分别构建 base 与 candidate，并真实执行 old -> new 切换。base 使用其自身的 `scripts/build-local.sh`，避免遗留 ZTNet 参数污染当前 ztncui-only 架构。

候选必须验证：

- PLANET identity 不变；
- current / previous world signing keys 不变；
- Controller identity 不变；
- Controller Network 数据保留；
- ztncui passwd / session 状态保留；
- candidate 健康启动；
- 升级后仍保持“一份共享二进制、两个隔离进程”。

### ARM64

main CI 通过后，Candidate workflow 使用 GitHub 原生 ARM64 Runner 构建并启动 ARM64 镜像，执行同一套集成与重启持久化测试，不使用 QEMU 作为运行验证。

## v0.5.0 发布门槛

1. 直接面向 `main` 的 v0.5.0 candidate PR：CI 全绿。
2. 同一 PR：Upgrade Test 全绿，证明真实 main/base -> v0.5.0 迁移。
3. 合并 main 后：多架构 `candidate` 成功发布，ARM64 smoke 全绿。
4. 个人研究环境手工试运行。
5. 创建 `v0.5.0` tag。
6. Release workflow 全绿并发布不可变镜像。
7. 最后手工 Promote Stable。

任何一步未通过，都不应仅凭“代码看起来正确”晋升 stable。
