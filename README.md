# ZeroTier Sovereign

一个以“可控、可复现、可备份”为目标的自建 ZeroTier 发行工程。

v0.3.0 将三个业务组件合并进 **一个 Docker 镜像**：

- 自建 PLANET / Root：现代 ZeroTier 开放构建分支
- Standalone Controller：独立持久化身份与网络配置
- ZTNet：现代 Web 管理界面

PostgreSQL 保持为独立容器，以便数据库升级、备份和恢复。

## 架构

```text
Internet / ZeroTier clients
          |
          | TCP+UDP 9994
          v
+--------------------------------------------------+
| zerotier-sovereign                               |
|                                                  |
| PLANET ZeroTier      /data/planet/one            |
|      |                                           |
|      +-- custom planet ----------------------+   |
|                                             |   |
| Controller ZeroTier   /data/controller/one  |   |
|      | REST API 127.0.0.1:9993              |   |
|      v                                      |   |
| ZTNet :3000 --------------------------------+   |
|                                                  |
| authenticated planet file service :3001          |
+-------------------------+------------------------+
                          |
                          | PostgreSQL
                          v
                  +---------------+
                  | postgres      |
                  | ZTNet DB      |
                  +---------------+
```

虽然是一个业务镜像，PLANET 与 Controller **仍是两套独立 ZeroTier 进程、两套 identity、两个工作目录**。合并的是部署单元，不是信任身份。

## 当前验证基线

版本以 `versions.env` 为唯一维护入口：

```env
SOVEREIGN_VERSION=0.3.0
PLANET_ZEROTIER_VERSION=1.16.2
CONTROLLER_ZEROTIER_VERSION=1.14.2
ZTNET_VERSION=v0.8.3
ZTNET_SOURCE_REF=v0.8.3
ZTNET_NODE_IMAGE=node:24-bookworm-slim
POSTGRES_IMAGE=postgres:17-alpine
```

`*_SOURCE_REF` 可以是 release tag，也可以是 40 位 commit SHA。自动更新流程会把新 release 解析到 immutable SHA，再提交候选升级 PR。

Controller **不会自动升级跨出 1.14.2 兼容分支**。ZeroTier 1.16 起 Controller 的源码/发行许可与默认构建方式发生了变化，因此这个组件单独维护，不和 PLANET 的现代版本自动联动。

## 快速开始

```bash
cp .env.example .env
```

至少修改：

```env
PLANET_IP_ADDR4=你的固定公网IPv4
ZTNET_AUTH_SECRET=使用 openssl rand -hex 32 生成
POSTGRES_PASSWORD=强随机密码
ZTNET_URL=http://127.0.0.1:3000
```

然后：

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

或：

```bash
docker exec zerotier-sovereign sovereignctl status
docker exec zerotier-sovereign sovereignctl version
```

## 端口

| 端口 | 协议 | 用途 | 默认宿主机绑定 |
|---|---|---|---|
| 9994 | UDP/TCP | 自建 PLANET / Root | `0.0.0.0` |
| 9993 | UDP | Controller 的 ZeroTier VL1 流量 | `0.0.0.0` |
| 3000 | TCP | ZTNet Web | `127.0.0.1` |
| 3001 | TCP | PLANET 文件下载 | `127.0.0.1` |

Controller 的 HTTP 管理 API 使用容器内部 `127.0.0.1:9993`，**不发布到宿主机**。ZTNet 与 Controller 同容器后，不再需要为 Web UI 开放 Controller API 网络访问。

远程使用 ZTNet 时，建议通过反向代理、VPN 或 SSH tunnel 暴露，而不是直接把 3000 裸露公网。

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
└── postgres/
    └── ... ZTNet database ...
```

最重要的是：

```text
data/planet/one/identity.secret
data/planet/world/current.c25519
data/planet/world/previous.c25519
data/controller/one/identity.secret
data/controller/one/controller.d/
data/postgres/
```

不要删除 PLANET 的 identity / world signing keys 后重新生成来“修复”生产环境；那会创建不同的信任根。

备份：

```bash
./scripts/backup.sh
```

备份包包含密钥和数据库，应按敏感凭据保存。

## PLANET 管理

查看：

```bash
docker exec zerotier-sovereign planetctl info
```

公网 IP 变化后，在保持 identity 和 world signing keys 的情况下重新签发：

```bash
docker exec \
  -e PLANET_IP_ADDR4=新的公网IP \
  zerotier-sovereign \
  planetctl regenerate

docker restart zerotier-sovereign
```

`planetctl` 会保证 World timestamp 单调递增。如果已有 `planet` 但签名密钥缺失，会拒绝启动，而不是静默生成另一个 World。

## GitHub Actions 维护模型

> 首次启用自动上游检查前，请在仓库 **Settings → Actions → General → Workflow permissions** 中允许 Actions 读写仓库内容，并允许 GitHub Actions 创建 Pull Request。否则 `upstream-check.yml` 可以检测更新，但无法自动提交升级 PR。

### `CI`

每次 push / PR：

1. ShellCheck / Python syntax
2. 自有功能单元测试
3. 在原生 amd64 Runner 上从源码构建统一镜像，并使用持久化 BuildKit cache
4. 启动 `zerotier-sovereign + PostgreSQL`
5. 检查 PLANET / Controller / ZTNet
6. 通过真实 Controller REST API 创建、读取、删除临时 Network
7. 重启容器，确认 PLANET identity、World keys、Controller identity 均未变化

### `Upgrade Test`

PR 会构建 base 与 candidate 两个镜像，复用同一套：

- PostgreSQL 数据
- PLANET 状态
- Controller 状态

然后完成 old -> new 切换，确认数据库 migration 可执行、DB volume 未被替换、candidate 可重新健康启动。

### `Upstream Check`

每天检查：

- `zerotier/ZeroTierOne` 最新正式 release（用于 PLANET）
- `sinamics/ztnet` 最新正式 release
- ZTNet 上游 Dockerfile 当前 Node.js 基础镜像

发现候选变化后：

1. Release tag 解析到真实 commit SHA
2. 更新 `versions.env`
3. 自动打开/刷新 `automation/upstream-refresh` PR
4. PR 必须经过 CI + Upgrade Test

如果已经 pin 住的 release tag 后来指向不同 commit，workflow 会直接失败并要求人工检查，而不会自动接受 retag。

Controller 的版本不会被这个 workflow 自动升级；当前 release tag只会被解析为不可变 SHA 来增强可复现性。

### `Publish Candidate`

`main` 上的 CI 成功后，自动发布：

```text
ghcr.io/<owner>/<repo>:candidate
ghcr.io/<owner>/<repo>:sha-xxxxxxxxxxxx
```

构建不再使用 QEMU 模拟 ARM64，而是并行使用 GitHub 原生 Runner：

```text
ubuntu-24.04      -> linux/amd64
ubuntu-24.04-arm  -> linux/arm64
                         ↓
                  merge manifest
```

两个架构拥有独立、长期复用的 BuildKit cache scope。main CI、Candidate 和 Release 会共享对应架构缓存；例如只升级 ZTNet 时，未变化的 ZeroTier PLANET / Controller 构建层应直接命中缓存。PR 使用独立 cache scope，不覆盖 main 的发布缓存。

公共仓库使用标准 GitHub-hosted ARM64 Runner；后续如果仓库改为私有仓库，需要重新确认对应 Actions 额度与计费策略。

### `Release`

创建与 `versions.env` 中 `SOVEREIGN_VERSION` 匹配的 Git tag，例如：

```bash
git tag v0.3.0
git push origin v0.3.0
```

会再次执行单测和完整集成冒烟测试。amd64 验证构建复用 main cache；随后 amd64 / arm64 在各自原生 Runner 上并行构建，并复用 Candidate 已生成的分架构缓存，然后发布不可变版本：

```text
ghcr.io/<owner>/<repo>:v0.3.0
ghcr.io/<owner>/<repo>:sha-xxxxxxxxxxxx
```

### `Promote Stable`

手工运行 `Promote Stable` workflow，输入已经发布的版本号，例如 `v0.3.0`。它只移动 manifest 标签：

```text
v0.3.0 -> stable
```

不会重新编译。

建议在 GitHub 为 `production` Environment 开启 required reviewers。这样 stable 晋升天然带人工确认。

生产 Compose 建议仍锁定明确版本，而不是直接使用 `stable`：

```env
SOVEREIGN_IMAGE=ghcr.io/<owner>/<repo>:v0.3.0
```

## 为什么 PostgreSQL 不合并进业务镜像

数据库有独立的数据生命周期、备份恢复、版本升级和健康检查。把 PLANET + Controller + ZTNet 合并后已经把日常部署简化成两个容器，再把 PostgreSQL 塞入同一个容器会明显降低恢复和升级质量，收益很小。

## 自有测试

本地无需 Docker 的测试：

```bash
make unit-test
```

覆盖：

- PLANET 首次初始化
- identity / world keys 持久化
- regenerate
- World timestamp 单调递增
- 缺失 signing key 时拒绝继续
- PLANET 文件服务认证
- Bearer / query-key 下载
- 目录穿越防护
- 版本文件同步

真实 Docker / Controller / PostgreSQL / ZTNet 行为交给 GitHub Actions 集成测试验证。

## 许可证边界

本仓库自己的脚本和 glue code 使用仓库中的 `LICENSE`。

ZeroTier、ZTNet、PostgreSQL 等第三方组件遵循各自上游许可；详见 `THIRD_PARTY_NOTICES.md`。特别是 ZeroTier 不同版本/组件的许可条件并不完全相同，升级 Controller 前应单独检查对应版本许可与构建方式。

## 上游

- ZeroTierOne: https://github.com/zerotier/ZeroTierOne
- ZeroTier Root / custom roots documentation: https://docs.zerotier.com/roots/
- ZTNet: https://github.com/sinamics/ztnet
