# Changelog

## 未发布

- GitHub Actions `Release` 工作流自动构建 Windows 便携包，发布版本号取自 `VERSION`（即 Rust 版本号）。
- 工作流支持推送 `v<Rust版本>` 标签，也支持在 Actions 页面手动运行并自动创建标签。
- 构建脚本新增校验：打包的 `rustc --version` 必须等于发布版本。
- 打包时按构建版本写入 `VERSION`，避免仓库文件与工具链版本不一致。
- 打包优先使用 7-Zip 最高压缩级别 `-mx=9`，并支持从 PATH 查找 7-Zip。
- 工具链目录改为动态查找，兼容 CI 的版本命名和本地的 `stable-*` 别名。

## 1.99.1 - 2026-11-02

- 首次发布。
- 项目版本号与 Rust 版本号一致。
- Windows x64 便携包：Rust 1.99.1、Cargo 1.99.1、rustup 1.29.2。
- 目标平台：`x86_64-pc-windows-gnu`。
- 包含 MinGW-w64 GCC 16.2.0（WinLibs、MSVCRT、POSIX 线程、SEH）。
- 包含 rustfmt、clippy、rust-analyzer、rust-src。
- 包含 `windows\configure-env.bat`、`windows\doctor.bat` 等启动和自检脚本。
- `shared/` 包含示例、C 测试、许可证和版本文档。
- Linux 支持尚未包含。
