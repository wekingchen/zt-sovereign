# v0.2.x -> v0.3.0 迁移

v0.3.0 将 PLANET、Controller 和 ZTNet 合并为一个业务镜像，但宿主机上的关键持久化目录仍沿用 v0.2 的路径，因此无需转换 identity、World key 或 PostgreSQL 数据。

## 1. 先在 v0.2 目录做完整备份

```bash
./scripts/backup.sh
```

另外建议手工再复制一份：

```bash
cp -a data data.pre-v0.3
```

## 2. 停止旧栈

```bash
docker compose down
```

不要删除 `data/`。

## 3. 用 v0.3 项目文件替换代码

保留：

```text
data/planet/
data/controller/
data/postgres/
```

v0.3 Compose 会继续直接挂载这三个目录。

## 4. 更新 `.env`

v0.2 的：

```env
PLANET_IMAGE=...
CONTROLLER_IMAGE=...
ZTNET_IMAGE=...
```

删除，改为：

```env
SOVEREIGN_IMAGE=zerotier-sovereign:local
```

保留原有：

```env
PLANET_IP_ADDR4 / PLANET_IP_ADDR6
PLANET_ZT_PORT
CONTROLLER_ZT_PORT
ZTNET_URL
ZTNET_AUTH_SECRET
POSTGRES_PASSWORD
POSTGRES_DB
POSTGRES_USER
```

可参考新的 `.env.example` 补齐缺失字段。

## 5. 验证并构建

```bash
./scripts/verify.sh
./scripts/build-local.sh
```

## 6. 启动 v0.3

```bash
docker compose up -d
```

检查：

```bash
./scripts/status.sh
```

重点确认：

```bash
docker exec zerotier-sovereign sovereignctl version
docker exec zerotier-sovereign planetctl info
```

以及：

- PLANET root node ID 与迁移前一致
- Controller node identity 与迁移前一致
- ZTNet 可以登录
- 旧 Network / Member 仍存在
- PostgreSQL migration 正常完成

## 7. 确认稳定后再删除旧镜像

v0.3 不依赖 v0.2 的三个业务镜像。确认运行稳定以后再清理旧镜像即可。

## 回滚

如果 v0.3 首次启动失败：

```bash
docker compose down
```

恢复 v0.2 项目文件，并继续使用原 `data/`。只要没有人为删除 PLANET/Controller identity、World signing keys 或 PostgreSQL 数据，回滚不需要重新生成网络身份。
