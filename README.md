# ZeroTier Sovereign

一个以 **可控、可复现、可备份、可迁移** 为目标的自建 ZeroTier 发行工程。

v0.4.0 将运行架构收敛为一个业务容器：

- 自建 PLANET / Root：现代 ZeroTier 开放构建
- Standalone Controller：独立身份、独立网络配置
- ztncui：源码已纳入本仓库维护，作为唯一 Web 管理界面
- PLANET 文件服务：用于受控分发自定义 `planet`

v0.4.0 **不再运行 ZTNet、Next.js、Prisma 或 PostgreSQL**。当前 amd64 的 ztncui-only 验证基线约为 **217 MiB 未压缩镜像体积**，CI 会在每次构建时继续报告实际体积。

## 架构

```text
Internet / ZeroTier clients
          |
          | TCP+UDP 9994
          v
+--------------------------------------------------+
| zerotier-sovereign                               |
|                                                  |
| PLANET ZeroTier        /data/planet/one          |
|   custom world / planet                          |
|                                                  |
| Controller ZeroTier    /data/controller/one      |
|   REST API 127.0.0.1:9993                       |
|          |                                       |
|          v                                       |
| ztncui :3000                                     |
|                                                  |
| authenticated planet file service :3001          |
+--------------------------------------------------+
```

PLANET 与 Controller 始终是 **两套独立 ZeroTier 进程、两套 identity、两个持久化目录**。合并的是部署单元，不是信任身份。

## 当前验证基线

版本以 `versions.env` 为维护入口：

```env
SOVEREIGN_VERSION=0.4.0
PLANET_ZEROTIER_VERSION=1.16.2
PLANET_ZEROTIER_SOURCE_REF=fc5c3ec22090b5b2a0f274e863651fe9ca489bf4
CONTROLLER_ZEROTIER_VERSION=1.14.2
CONTROLLER_ZEROTIER_SOURCE_REF=185a3a2c76e6bf1b1c0415871f43076638eb007c
MKWORLD_SOURCE_REF=3ba175a682d03edd72516d830667ee08fe3cf262
NODEJS_IMAGE=node:24-alpine3.24
```

其中：

- `PLANET_ZEROTIER_SOURCE_REF` 与 `CONTROLLER_ZEROTIER_SOURCE_REF` 固定到不可变 commit，保证可复现。
- Controller 不会由自动更新流程跨出当前兼容版本。
- `MKWORLD_SOURCE_REF` 只用于取得生成 PLANET world 的 `ztmkworld` helper；ZTNet Web 应用本身不进入运行镜像。
- ztncui 源码位于 `ui/ztncui/`，不在镜像构建时动态拉取。

## 快速开始

先准备配置：

```bash
cp .env.example .env
```

至少设置一个可被客户端访问的固定公网地址：

```env
PLANET_IP_ADDR4=你的固定公网IPv4
# 或 PLANET_IP_ADDR6=你的固定公网IPv6
```

然后执行：

```bash
./scripts/init.sh
./scripts/verify.sh
./scripts/build-local.sh
docker compose up -d
```

查看状态：

```bash
./scripts/status.sh
```

或直接：

```bash
docker exec zerotier-sovereign sovereignctl status
docker exec zerotier-sovereign sovereignctl version
```

## ztncui 首次登录

默认情况下，`.env` 中：

```env
ZTNCUI_ADMIN_PASSWORD=
```

保持为空即可。首次启动时容器会：

1. 随机生成一次性管理员密码；
2. 将密码以 0600 权限写入 `/data/ztncui/initial-admin-password`；
3. 创建 `admin` 用户并要求首次登录后修改密码；
4. 修改成功后删除一次性密码文件。

查看首次密码：

```bash
docker exec zerotier-sovereign sovereignctl ztncui-initial-password
```

用户名为：

```text
admin
```

如果希望首次启动就使用明确指定的密码，可以在 `.env` 中设置：

```env
ZTNCUI_ADMIN_PASSWORD=你的强密码
```

这种模式不会创建一次性密码文件。

## 端口

| 端口 | 协议 | 用途 | 默认宿主机绑定 |
|---|---|---|---|
| 9994 | UDP/TCP | 自建 PLANET / Root | `0.0.0.0` |
| 9993 | UDP | Controller 的 ZeroTier VL1 流量 | `0.0.0.0` |
| 3000 | TCP | ztncui Web | `127.0.0.1` |
| 3001 | TCP | PLANET 文件下载 | `127.0.0.1` |

Controller 的 HTTP 管理 API 只监听容器内部 `127.0.0.1:9993`，不会发布到宿主机。

ztncui 默认也只绑定宿主机回环地址。远程管理建议通过 VPN、反向代理或 SSH tunnel，而不是直接把 3000 裸露到公网。

## 持久化数据

```text
data/
├── planet/
│   ├── one/
│   │   ├── identity.secret
│   │   ├── identity.public
│   │   └── planet
│   ├── world/
│   │   ├── current.c25519
│   │   ├── previous.c25519
│   │   └── world.bin
│   ├── dist/
│   │   ├── planet
│   │   └── *.moon
│   └── config/
│       └── file_server.key
├── controller/
│   └── one/
│       ├── identity.secret
│       ├── authtoken.secret
│       └── controller.d/
└── ztncui/
    ├── passwd
    ├── session.secret
    └── storage/
```

最关键的数据包括：

```text
data/planet/one/identity.secret
data/planet/world/current.c25519
data/planet/world/previous.c25519
data/controller/one/identity.secret
data/controller/one/controller.d/
data/ztncui/
```

不要通过删除 PLANET identity 或 world signing keys 来“重置”生产环境；那会产生一个新的信任根。

## 从 v0.3.x 升级到 v0.4.0

v0.4.0 是一次运行架构迁移，而不只是换镜像标签。

自动 Upgrade Test 会真实启动当前 base 版本，再切换到候选版本并验证：

- PLANET identity 不变；
- `current.c25519` / `previous.c25519` 不变；
- Controller identity 不变；
- Controller 已创建的 Network 数据仍存在；
- ztncui 密码与 session 状态保持；
- 新架构可以重新健康启动。

### PostgreSQL / ZTNet 数据

v0.4.0 不再消费 PostgreSQL，也不再运行 ZTNet，因此旧的：

```text
data/postgres/
```

不会迁移进新架构。

升级前建议先完整备份旧环境。确认 v0.4.0 工作正常并经过自己的回滚窗口后，再决定是否归档或删除旧 PostgreSQL 数据。

### 备份

```bash
./scripts/backup.sh
```

备份包包含 PLANET/Controller 身份、world signing keys、ztncui 凭据/session 和应用配置，应按敏感数据保存。

## PLANET 管理

查看当前信息：

```bash
docker exec zerotier-sovereign planetctl info
```

固定公网 IP 变化后，在保持 identity 与 world signing keys 的情况下重新签发：

```bash
docker exec \
  -e PLANET_IP_ADDR4=新的公网IP \
  zerotier-sovereign \
  planetctl regenerate

docker restart zerotier-sovereign
```

`planetctl` 会保证 World timestamp 单调递增。如果已有 `planet` 但签名密钥缺失，会拒绝继续，而不是静默生成另一套 World。

## ztncui 源码维护

ztncui 已直接纳入：

```text
ui/ztncui/
```

初始来源：

- Upstream: `key-networks/ztncui`
- Imported commit: `1b2284864de48d2dcae22582fff122fe24909c3d`
- Upstream version: `0.8.14`

来源记录见 `ui/ztncui/UPSTREAM.md`。后续修改直接作为本项目代码维护，不依赖 git submodule，也不需要在 Docker build 时从上游下载。

## GitHub Actions

### CI

每次 PR / main push：

1. ShellCheck、Python/JavaScript syntax；
2. 单元测试；
3. 校验 `versions.env` 与 `.env.example` 同步；
4. 原生 amd64 构建；
5. 输出运行镜像体积与主要目录占用；
6. 启动完整 ztncui-only stack；
7. 通过真实 Controller API 做集成验证；
8. 重启容器并验证持久化。

### Upgrade Test

每个 PR 会构建 **base 分支镜像 + candidate 镜像**，真实执行 old → new 切换。

迁移测试通过 Docker daemon 复制 root-owned 持久化文件，避免宿主 Runner 因 0600 权限误报失败。

### Upstream Check

每天自动检查：

- `zerotier/ZeroTierOne` 最新正式版本，用于 PLANET；
- 当前 Controller 兼容 tag 是否仍解析到已固定 commit。

它不会自动升级 Controller 跨版本，也不会再把 ZTNet 当运行时上游。ztncui 已由本仓库维护；`ztmkworld` helper 的来源 commit 单独固定、人工审查。

### Publish Candidate

main 的 CI 成功后，使用 GitHub 原生 Runner 分别构建：

```text
ubuntu-24.04      -> linux/amd64
ubuntu-24.04-arm  -> linux/arm64
                         ↓
                  multi-arch manifest
```

并发布：

```text
ghcr.io/<owner>/<repo>:candidate
ghcr.io/<owner>/<repo>:sha-xxxxxxxxxxxx
```

ARM64 会在原生 ARM Runner 上执行实际集成与重启持久化测试，不使用 QEMU 冒充运行验证。

### Release

v0.4.0 合并 main 并确认 candidate 后，创建与 `versions.env` 匹配的 tag：

```bash
git tag v0.4.0
git push origin v0.4.0
```

Release workflow 会重新执行 amd64 验证，并原生构建 amd64 / arm64，最后发布：

```text
ghcr.io/<owner>/<repo>:v0.4.0
ghcr.io/<owner>/<repo>:sha-xxxxxxxxxxxx
```

### Promote Stable

手工运行 `Promote Stable` workflow，将已经验证的明确版本移动为：

```text
v0.4.0 -> stable
```

生产部署仍建议锁定明确版本：

```env
SOVEREIGN_IMAGE=ghcr.io/<owner>/<repo>:v0.4.0
```

而不是直接依赖会移动的 `stable` 标签。

## 本地测试

无需 Docker 的测试：

```bash
make unit-test
```

覆盖包括：

- PLANET 首次初始化；
- identity / world keys 持久化；
- regenerate；
- World timestamp 单调递增；
- signing key 缺失时拒绝继续；
- PLANET 文件服务认证；
- Bearer / query-key 下载；
- 目录穿越防护；
- 版本文件同步。

真实 Docker、Controller 与 ztncui 行为由 GitHub Actions 集成测试验证。

## 许可证边界

本仓库自己的脚本和 glue code 使用仓库中的 `LICENSE`。

ZeroTier、ztncui、`ztmkworld` helper、Node.js、Alpine、Rust 与 npm 依赖分别遵循各自上游许可证。特别是 `ztmkworld` 所在的固定 `ztnodeid` 源码树包含不同许可证声明，不能简单按“整个 ZTNet 仓库一个许可证”处理。

详见 `THIRD_PARTY_NOTICES.md`。

## 上游

- ZeroTierOne: https://github.com/zerotier/ZeroTierOne
- ZeroTier custom roots: https://docs.zerotier.com/roots/
- ztncui: https://github.com/key-networks/ztncui
- ztmkworld provenance: https://github.com/sinamics/ztnet
