# ZeroTier Sovereign

一个以 **可控、可复现、可备份、可迁移** 为目标的自建 ZeroTier 发行工程。

> **用途限制：本项目仅用于个人、非商业研究与学习。** 当前 Controller 使用 ZeroTier 1.16.2 的 source-available Controller 组件（`ZT_NONFREE=1`）；商业、组织生产或服务化使用不在本项目授权范围内。第三方组件仍分别遵循各自许可证，详见 `LICENSE` 与 `THIRD_PARTY_NOTICES.md`。

v0.6.0 在 v0.5.0 简体中文界面的基础上，对项目维护的 ztncui 进行完整现代化改造，同时保持业务逻辑、Controller API、路由和持久化结构不变：

- 共享 ZeroTier 1.16.2 二进制：仅构建和存储一份，启用 `ZT_NONFREE=1`
- PLANET / Root 进程：独立端口、identity 和数据目录
- Standalone Controller 进程：独立端口、identity、网络配置和数据目录
- ztncui：源码已纳入本仓库维护，作为唯一 Web 管理界面；采用现代响应式后台设计，支持桌面端和移动端
- PLANET 文件服务：用于受控分发自定义 `planet`

v0.6.0 **不运行 ZTNet、Next.js、Prisma 或 PostgreSQL**。ZeroTier 仍只编译一次并保留一份 `zerotier-one`；本次 UI 改造仅调整 Pug 展示结构与 CSS 设计系统，不改变 ZeroTier API、表单字段名、URL、Controller 行为或持久化结构。

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

PLANET 与 Controller 始终是 **两套独立 ZeroTier 进程、两套 identity、两个持久化目录**，但两者执行同一个 `/opt/zerotier/zerotier-one` 文件。统一的是二进制和版本，不是进程或信任身份。

## 当前验证基线

版本以 `versions.env` 为维护入口：

```env
SOVEREIGN_VERSION=0.6.0
ZEROTIER_VERSION=1.16.2
ZEROTIER_SOURCE_REF=fc5c3ec22090b5b2a0f274e863651fe9ca489bf4
MKWORLD_SOURCE_REF=3ba175a682d03edd72516d830667ee08fe3cf262
NODEJS_IMAGE=node:24-alpine3.24
```

其中：

- `ZEROTIER_SOURCE_REF` 固定到不可变 commit，保证共享二进制可复现。
- PLANET 与 Controller 使用同一个 ZeroTier 正式版本候选；Upstream Check 只负责开 PR，必须通过真实 ztncui CRUD、重启持久化和升级测试后才允许合并。
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

## ztncui 现代化界面

v0.6.0 起，ztncui 在完整简体中文基础上升级为现代响应式控制台：

- 深色品牌导航、统一内容卡片、现代按钮/表单/告警和状态徽章；
- 首页改为 Controller 状态仪表盘；
- 网络列表、网络详情、成员状态、路由、DNS、地址池、管理员等页面统一视觉体系；
- 桌面端采用最大 1440px 的内容布局，移动端按 iOS 优先策略重新排版导航、按钮、表单、详情字段和数据列表；
- 网络、管理员、成员、路由、IP 分配池和 IP 分配等表格在手机上自动转为纵向字段卡片，优先消除横向拖动；
- 常用触控控件最小高度约 44px；iPhone Safari 输入框使用 16px 字号避免聚焦自动放大；
- 支持 `safe-area-inset-*`、`100dvh` 和 `viewport-fit=cover`，适配刘海、灵动岛、Home Indicator、Safari 动态地址栏以及横竖屏切换；
- 额外针对约 320–430px 的常见 iPhone 逻辑宽度优化，长 Network ID / IPv6 地址允许自然断行，不撑宽页面；
- 删除、空状态、错误页采用明确的视觉语义；
- 不更改现有业务逻辑、API、路由、表单字段名与持久化格式。

CI 中的 `test_ztncui_modern_ui.py` 会检查响应式 viewport、核心设计组件、表格响应式结构和关键功能钩子，Docker 构建还会编译所有 Pug 模板。

## ztncui 简体中文界面

v0.5.0 起，ztncui 默认使用简体中文（`zh-CN`）：

- 首页、导航、登录、管理员、网络、成员、路由、DNS、IP 分配等页面全部汉化；
- 后端生成的页面标题、表单校验、登录提示和可见错误信息全部汉化；
- 网络/成员详情中的常见 ZeroTier API 字段通过 `ui/ztncui/src/locales/zh-cn.js` 映射为中文显示名；
- `ZeroTier`、`IPv4`、`IPv6`、`CIDR`、`DNS`、`MTU` 等标准技术术语保留原名；
- 底层 API 字段、URL、配置键和数据文件保持不变，因此不会影响兼容性。

CI 中的 `test_ztncui_zh_cn.py` 会阻止常见英文 UI 文案重新混入。

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

### 忘记或需要重置 ztncui 密码

在容器 Console 中直接执行：

```bash
sovereignctl ztncui-reset-password
```

默认重置 `admin`，命令会隐藏输入并要求输入两遍新密码。成功后会：

1. 原子更新 `/data/ztncui/passwd` 中对应用户的 Argon2 密码哈希；
2. 删除旧的 `initial-admin-password`（如果存在）；
3. 轮换 `session.secret`，使已有浏览器登录会话失效；
4. 自动重启容器，使新密码立即生效。

因此在 Portainer Console 中执行后连接短暂断开是正常现象。项目默认的 `restart: unless-stopped` 会自动拉起容器。

也可以自动生成强随机密码：

```bash
sovereignctl ztncui-reset-password --generate
```

重置其他管理员：

```bash
sovereignctl ztncui-reset-password --user 用户名
```

自动化或维护脚本若希望自行决定何时重启：

```bash
sovereignctl ztncui-reset-password --generate --no-restart
```

使用 `--no-restart` 后必须手工重启容器，新密码才会被正在运行的 ztncui 进程重新载入。

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
4. 原生 amd64 构建一份共享 ZeroTier 二进制；
5. 输出运行镜像体积与主要目录占用；
6. 启动完整 ztncui-only stack；
7. 验证共享 ZeroTier 安装并通过真实 Controller API 做集成验证；
8. 重启容器并验证持久化。

### Upgrade Test

每个 PR 会构建 **base 分支镜像 + candidate 镜像**，真实执行 old → new 切换。

迁移测试通过 Docker daemon 复制 root-owned 持久化文件，避免宿主 Runner 因 0600 权限误报失败。

### Upstream Check

每天自动检查 `zerotier/ZeroTierOne` 最新正式版本，并更新唯一的 `ZEROTIER_VERSION` / `ZEROTIER_SOURCE_REF` 候选。

自动化只会创建或刷新 PR，不会直接合并。共享 ZeroTier 候选必须通过真实 Controller API、ztncui CRUD、重启持久化与 Upgrade Test 后才可进入 main。ztncui 已由本仓库维护；`ztmkworld` helper 的来源 commit 单独固定、人工审查。

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
goordonchen/zt-sovereign:candidate
goordonchen/zt-sovereign:sha-xxxxxxxxxxxx
```

ARM64 会在原生 ARM Runner 上执行实际集成与重启持久化测试，不使用 QEMU 冒充运行验证。

### Release

v0.6.0 合并 main 并确认 candidate 后，创建与 `versions.env` 匹配的 tag：

```bash
git tag v0.6.0
git push origin v0.6.0
```

Release workflow 会重新执行 amd64 验证，并原生构建 amd64 / arm64，最后发布：

```text
goordonchen/zt-sovereign:v0.6.0
goordonchen/zt-sovereign:sha-xxxxxxxxxxxx
```

### Promote Stable

手工运行 `Promote Stable` workflow，将已经验证的明确版本移动为：

```text
v0.6.0 -> stable
```

生产部署仍建议锁定明确版本：

```env
SOVEREIGN_IMAGE=goordonchen/zt-sovereign:v0.6.0
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

本项目整体定位为 **个人、非商业研究用途**。仓库自有脚本与 glue code 使用根目录 `LICENSE` 中的 Personal Non-Commercial Research License；它不覆盖第三方代码或第三方衍生代码。

Controller 使用 ZeroTier 1.16.2 `nonfree/controller`，构建时启用 `ZT_NONFREE=1`。该组件采用 ZeroTier Source-Available License，只允许其定义范围内的非商业用途；运行镜像保留许可副本 `/usr/local/share/zerotier-sovereign/ZEROTIER-NONFREE-LICENSE.md`。

ztncui（GPLv3）、`ztmkworld` helper、Node.js、Alpine、Rust 与 npm 依赖继续分别遵循各自上游许可证。详见 `THIRD_PARTY_NOTICES.md`。

## 上游

- ZeroTierOne: https://github.com/zerotier/ZeroTierOne
- ZeroTier custom roots: https://docs.zerotier.com/roots/
- ztncui: https://github.com/key-networks/ztncui
- ztmkworld provenance: https://github.com/sinamics/ztnet
