# 版本与来源

采集日期：2026-11-02

## 发布包版本

- rust-portable：1.99.1
- 项目版本号与 Rust 版本号一致。

## 平台范围

- Windows x64：已包含完整工具链。
- Linux：暂未包含。`linux/` 目录只作预留。

## Windows 已安装工具链

```text
rustc 1.99.1 (58cf8f9c3 2026-10-13)
cargo 1.99.1 (5f94df478 2026-08-27)
rustup 1.29.2 (d8c92c676 2026-10-21)
default host: x86_64-pc-windows-gnu
default toolchain: stable-x86_64-pc-windows-gnu
rustup profile: minimal
```

已安装 Rust 组件：

```text
cargo-x86_64-pc-windows-gnu
clippy-x86_64-pc-windows-gnu
rust-analyzer-x86_64-pc-windows-gnu
rust-mingw-x86_64-pc-windows-gnu
rust-src
rust-std-x86_64-pc-windows-gnu
rustc-x86_64-pc-windows-gnu
rustfmt-x86_64-pc-windows-gnu
```

MinGW-w64（WinLibs personal build）：

```text
gcc-16.2.0-mingw-w64msvcrt-14.0.0-r2
GCC 16.2.0
GDB 18.1
MinGW-w64 14.0.0 (MSVCRT)
GNU Binutils 2.47.20260726
GNU Make 4.4.1
CMake 4.4.3
Ninja 1.13.2
Thread model: posix
Runtime library: MSVCRT
```

## 下载来源与校验

### rustup-init.exe

- 文件：`windows/bootstrap/rustup-init.exe`
- URL: <https://static.rust-lang.org/rustup/archive/1.29.2/x86_64-pc-windows-gnu/rustup-init.exe>
- Version: 1.29.2 (d8c92c676 2026-10-21)
- SHA256:

```text
d2845ad914acf5add202100c0a7ddf19ab1c3e52521e12841bafff13888e49bb
```

### WinLibs MinGW-w64

- 位置：`windows/toolchain/mingw64/`
- Release: `16.2.0posix-14.0.0-msvcrt-r2`
- File: `winlibs-x86_64-posix-seh-gcc-16.2.0-mingw-w64msvcrt-14.0.0-r2.zip`
- URL: <https://github.com/brechtsanders/winlibs_mingw/releases/download/16.2.0posix-14.0.0-msvcrt-r2/winlibs-x86_64-posix-seh-gcc-16.2.0-mingw-w64msvcrt-14.0.0-r2.zip>
- SHA256:

```text
1b90ec73c96e6905a913746b56fb6b20122422787029810d3afc6a3b440f2322
```

### Windows Rust 工具链

安装命令（等价于本包的安装方式）：

```bat
set CARGO_HOME=<包根目录>\windows\cargo
set RUSTUP_HOME=<包根目录>\windows\rustup
windows\bootstrap\rustup-init.exe -y --no-modify-path --profile minimal --default-host x86_64-pc-windows-gnu --default-toolchain <VERSION>-x86_64-pc-windows-gnu
windows\cargo\bin\rustup.exe component add rustfmt clippy rust-analyzer rust-src
windows\cargo\bin\rustup.exe set profile minimal
```

> `<VERSION>` 取包内 `VERSION` 文件中的 Rust 版本，例如 `1.99.1`。
> 不要写成 `stable`，否则会安装当时的最新 stable，而不是发布版本。

> 为了控制体积，没有安装 `llvm-tools`、`rust-docs`、`rust-analysis`。
> 需要时可用 `rustup component add <名称>` 重新安装。

## 验证记录

- `windows\doctor.bat`：rustc/cargo/rustfmt/clippy/rust-analyzer/gcc/g++ 检查通过。
- 临时 Cargo 项目编译并运行通过。
- C / C++ 程序编译运行通过。
- Rust 经 `cc` crate 编译并链接本地 C 代码通过。
- 便携包在无空格路径下复制、迁移和卸载通过。
- 含空格路径会被 Windows 启动脚本明确拒绝（MinGW GCC 的内部限制）。
- Linux 工具链未包含，未验证 Linux。
