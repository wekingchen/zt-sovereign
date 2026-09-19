# Validation status — v0.3.0

## 已在当前生成环境实际执行

- 所有 Bash 脚本 `bash -n` 语法检查
- Python `py_compile`
- Compose / GitHub Actions YAML 解析检查
- `tests/unit/test_planetctl.sh`
  - 首次初始化
  - ensure 重用
  - regenerate
  - identity 不变
  - signing key 不变
  - World timestamp 单调递增
  - endpoint 更新
  - signing key 缺失时拒绝继续
- `tests/unit/test_file_server.py`
  - healthz
  - 未授权 401
  - query key 下载
  - Bearer token 下载
  - moon 下载
  - 路径穿越拒绝
  - 下载密钥持久化
- `tests/unit/test_version_sync.sh`

## 当前环境无法声称已经执行

当前生成环境没有可用 Docker daemon，也不能直接访问 GitHub 构建依赖，因此这里没有伪称以下测试已完成：

- ZeroTier 1.16.x 真实源码编译
- ZeroTier 1.14.2 Controller 真实源码编译
- ZTNet v0.8.3 真实源码编译
- amd64 / arm64 buildx
- Supervisor 下两个 ZeroTier daemon + ZTNet 的真实运行
- PostgreSQL migration
- Controller REST API Network CRUD
- restart persistence
- old -> candidate upgrade

这些测试已经编码进 `.github/workflows/`，第一次推入 GitHub 后应以 Actions 结果为准。

## 发布门槛

不应因为静态测试通过就把 v0.3.0 当成生产验证完成。建议顺序：

1. 推入私有 GitHub 仓库。
2. CI 全绿。
3. Upgrade Test 全绿（如果 base 已是 v0.3 架构）。
4. `candidate` 多架构镜像生成成功。
5. 在非关键节点手工试运行。
6. 创建 `v0.3.0` tag。
7. Release workflow 全绿并发布不可变镜像。
8. 最后再手工 Promote Stable。
