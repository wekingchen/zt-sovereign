# Third-party notices

本项目仅定位为 **个人、非商业研究与学习用途**。本文件记录第三方组件的来源与许可证边界，不替代各上游许可证正文，也不构成法律意见。

## ZeroTierOne

Source: https://github.com/zerotier/ZeroTierOne

当前验证基线只构建一份 ZeroTier 1.16.2 二进制：

- Build: `make ZT_NONFREE=1`，包含 `nonfree/controller` 中的 FileDB Controller。
- Runtime: 同一个 `/opt/zerotier/zerotier-one` 分别启动 PLANET 与 Controller 两个独立进程。
- Isolation: 两个进程使用不同端口、identity、home 与持久化目录。
- Pinned source commit: `fc5c3ec22090b5b2a0f274e863651fe9ca489bf4`

ZeroTier 1.16.2 的 `nonfree/LICENSE.md` 将 Controller 定义为 source-available 组件，并允许其定义范围内的个人非商业、教育研究及有限评估用途；商业使用需要另行获得 ZeroTier 授权。本项目不面向商业、组织生产或服务化使用。

运行镜像保留该许可证正文：

```text
/usr/local/share/zerotier-sovereign/ZEROTIER-NONFREE-LICENSE.md
```

Upstream Check 可以提出新的共享 ZeroTier 正式版本候选，但不会自动合并。更新必须经过 CI、真实 Controller API、ztncui CRUD、重启持久化与升级测试。

## ztncui

Source: https://github.com/key-networks/ztncui

本项目已将 ztncui 固定源码导入 `ui/ztncui/` 并直接维护：

- Imported commit: `1b2284864de48d2dcae22582fff122fe24909c3d`
- Upstream version: `0.8.14`
- Upstream license: GNU GPL v3
- Provenance: `ui/ztncui/UPSTREAM.md`
- License copy: `ui/ztncui/LICENSE`

ztncui 及其衍生修改继续遵循 GPLv3，不受仓库根目录针对项目自有代码的非商业许可证替代。

## ztmkworld build helper

Source repository: https://github.com/sinamics/ztnet

ZeroTier Sovereign **不运行或分发 ZTNet Web 应用本身**。当前只从 `versions.env` 中固定的不可变 commit `MKWORLD_SOURCE_REF` 取得 `ztnodeid/build/<arch>/ztmkworld`，作为生成自定义 PLANET world 的辅助程序。

当前固定来源：

- Source commit: `3ba175a682d03edd72516d830667ee08fe3cf262`
- Source subtree: `ztnodeid/`
- Runtime provenance: 镜像内 `/usr/local/share/zerotier-sovereign/mkworld-source-commit`

固定的 `ztnodeid` 源码树包含多种许可证声明，应以固定 commit 中对应文件的实际版权/许可证为准并保持来源可追溯。

## Alpine Linux / Node.js / Rust / npm dependencies

运行镜像基于 Alpine 版 Node.js。构建 ZeroTier 时使用 Alpine 工具链与 Rust；构建项目维护的 ztncui 时安装其 npm 运行依赖。这些软件与依赖分别遵守各自上游许可证。
