# 版本与来源

采集日期：2026-11-02

## 发布包版本

- rust-portable：1.99.1
- 项目版本号与 Rust 版本号一致。
- 同一 Rust 版本的修订包使用 `v1.99.1-r<N>` 标签，包内 Rust 版本不变。

## 平台范围

- Windows x64：完整便携工具链。
- Linux x64：离线安装包，包含 Rust 官方独立组件。
- Linux 目标：`x86_64-unknown-linux-gnu`。
- Linux 最低要求：glibc 2.17、kernel 3.2。
- Linux 验证环境：Oracle Linux 8.10 x86_64（glibc 2.28、kernel 4.18）。

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

## Linux 已安装组件

Linux 包使用 Rust 官方独立安装器。
Linux 包不使用 rustup。

组件版本与 Rust 1.99.1 发布一致：

```text
rustc 1.99.1 (58cf8f9c3 2026-10-13)
cargo 1.99.1 (5f94df478 2026-08-27)
rustfmt 1.10.0-stable (58cf8f9c35 2026-10-13)
clippy 0.1.99 (58cf8f9c35 2026-10-13)
rust-analyzer 1.99.1 (58cf8f9 2026-10-13)
default target: x86_64-unknown-linux-gnu
```

系统依赖由目标机提供：

```text
gcc
gcc-c++
make
```

Linux 包不包含：

- rust-docs
- llvm-tools
- rust-analysis
- rustc-dev

需要时可以执行 `add-component.sh` 补装。

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

## Linux 下载来源与校验

### 发布清单

- URL: <https://static.rust-lang.org/dist/channel-rust-1.99.1.toml>
- SHA256:

```text
fb152be80975c194aa5fc684b2aec3a6e14e2b855efe2faa4e5f8ae6e590f463
```

`scripts/prepare-linux.sh` 读取该清单，并选择 `x86_64-unknown-linux-gnu` 的 xz 包。

### 组件包

| 组件 | 文件 | SHA256 |
| --- | --- | --- |
| rustc | `rustc-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `2ff05ff9c08a90861e7f6e4065b40a8b87463b4576186fd613871c3e37f2091f` |
| cargo | `cargo-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `53f3521949404d595efb06a55c12c5658d4ed1c75566f33d3d514eaebe70bd8a` |
| rust-std | `rust-std-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `109b074225bf5b9ea3820890876bfdf4ed161adbfaf94b2b4b5984c85ee5d958` |
| rust-src | `rust-src-1.99.1.tar.xz` | `e485a88c45db546b73571df7bebfcb4454ba4fb552c492e25fc5b00eeb5bf22d` |
| rustfmt | `rustfmt-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `e3b36c4c7ec3486c059d8067ff48787676612007123aad7a4e8ec12c48ee9ba2` |
| clippy | `clippy-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `458339712a058e52cc4522ff9ef8b59cd1ea1340312216cd94194c464a3f6dc5` |
| rust-analyzer | `rust-analyzer-1.99.1-x86_64-unknown-linux-gnu.tar.xz` | `5f2613d62003fc8cbe788d4ae409359c91c241ba248adbefe032df8bb77357bf` |

官方文件位于：

```text
https://static.rust-lang.org/dist/2026-10-15/<file>
```

### 安装命令

官方组件的安装方式：

```bash
tar -xJf rustc-1.99.1-x86_64-unknown-linux-gnu.tar.xz -C /tmp
bash /tmp/rustc-1.99.1-x86_64-unknown-linux-gnu/install.sh \
  --prefix=/opt/rust-portable --disable-ldconfig
```

发布包中的 `linux/install.sh` 会自动完成全部组件的安装和校验。

## 验证记录

- `windows\doctor.bat`：rustc/cargo/rustfmt/clippy/rust-analyzer/gcc/g++ 检查通过。
- 临时 Cargo 项目编译并运行通过。
- C / C++ 程序编译运行通过。
- Rust 经 `cc` crate 编译并链接本地 C 代码通过。
- 便携包在无空格路径下复制、迁移和卸载通过。
- 含空格路径会被 Windows 启动脚本明确拒绝（MinGW GCC 的内部限制）。
- Linux：7 个组件的 SHA256 与官方发布清单一致。
- Linux：Oracle Linux 8.10 x86_64 离线容器中安装成功。
- Linux：rustc、cargo、rustfmt、clippy、rust-analyzer 均可运行。
- Linux：`cargo new` 和 `cargo metadata` 在 `CARGO_NET_OFFLINE=true` 下通过。
- Linux：`add-component.sh` 补装 rustfmt 通过。
- Linux：`uninstall.sh` 删除前缀和 `/etc/profile.d/rust-portable.sh` 通过。
- Linux：完整 `doctor.sh`（含 gcc 编译和链接）由 GitHub Actions 的 Oracle Linux 8 容器测试覆盖。
