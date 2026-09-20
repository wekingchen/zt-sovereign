# v0.3.x -> v0.4.0 迁移

v0.4.0 不只是镜像瘦身，而是从 **ZTNet + PostgreSQL** 切换到 **项目内维护的 ztncui**。PLANET 与 Controller 的信任身份继续沿用；ZTNet/PostgreSQL 则退出运行架构。

## 1. 先备份 v0.3

在旧版本目录执行：

```bash
./scripts/backup.sh
```

建议另外保留一份完整 `data/` 与旧 `.env`，直到 v0.4.0 经过自己的回滚窗口。

最不能丢失的是：

```text
data/planet/one/identity.secret
data/planet/world/current.c25519
data/planet/world/previous.c25519
data/controller/one/identity.secret
data/controller/one/controller.d/
```

不要通过重新生成这些文件来“修复升级”。

## 2. 停止 v0.3

```bash
docker compose down
```

不要删除 `data/`。

## 3. 切换到 v0.4.0 项目文件

v0.4.0 使用：

```text
data/planet/
data/controller/
data/ztncui/
```

旧的：

```text
data/postgres/
```

不再被运行时挂载或消费。先保留归档，不要在首次升级时立即删除。

## 4. 更新 .env

保留 PLANET / Controller 的网络参数，例如：

```env
PLANET_IP_ADDR4=...
PLANET_IP_ADDR6=...
PLANET_ZT_PORT=9994
CONTROLLER_ZT_PORT=9993
```

删除旧的 ZTNet/PostgreSQL 配置，例如：

```env
ZTNET_URL=...
ZTNET_AUTH_SECRET=...
POSTGRES_PASSWORD=...
POSTGRES_DB=...
POSTGRES_USER=...
```

以新的 `.env.example` 为准补齐配置。

ztncui 首次管理员密码建议保持：

```env
ZTNCUI_ADMIN_PASSWORD=
```

为空时会自动生成随机一次性密码。

## 5. 验证并构建

```bash
./scripts/verify.sh
./scripts/build-local.sh
```

## 6. 启动 v0.4.0

```bash
docker compose up -d
```

检查：

```bash
./scripts/status.sh
docker exec zerotier-sovereign sovereignctl version
docker exec zerotier-sovereign planetctl info
```

首次登录 ztncui 时获取密码：

```bash
docker exec zerotier-sovereign sovereignctl ztncui-initial-password
```

## 7. 核对迁移不变量

至少确认：

- PLANET root node ID 与升级前一致；
- World signing keys 没有变化；
- Controller node identity 一致；
- 原 Controller Network / Member 数据仍存在；
- ztncui 可以创建、查看、修改网络；
- 容器重启后上述状态仍保留。

仓库的 Upgrade Test 会自动验证其中的核心身份、World key、Controller Network 和 ztncui 持久化不变量。

## PostgreSQL 数据何时删除

v0.4.0 不会读取旧 PostgreSQL。建议在：

1. v0.4.0 已完成实际节点验证；
2. 已确认无需回滚到 ZTNet；
3. 已另行归档旧备份；

之后再手工处理 `data/postgres/`。

## 回滚

如果 v0.4.0 验证失败：

1. 停止 v0.4.0；
2. 恢复 v0.3 项目文件与旧 `.env`；
3. 使用之前保留的 `data/`（尤其包括 `data/postgres/`）启动 v0.3。

只要没有覆盖或删除 PLANET/Controller 的 identity、World signing keys 和旧 PostgreSQL 数据，回滚不需要重新创建 ZeroTier 信任身份。
