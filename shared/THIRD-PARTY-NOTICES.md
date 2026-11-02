# 第三方组件许可说明

本包分发 Windows x64 便携工具链和 Linux x64 离线安装包。
Windows 包包含 Rust 工具链和 WinLibs MinGW-w64 构建。
Linux 包只包含 Rust 官方独立组件。
Linux 包不包含 GCC、glibc、binutils 或 make；这些由目标系统的软件仓库提供。

各组件版权归其各自作者所有。本包未修改这些二进制文件。
许可证文本在 `shared/licenses/` 目录。

## Rust 工具链 / Cargo

- 项目：Rust Programming Language
- 许可证：MIT OR Apache-2.0
- 来源：<https://static.rust-lang.org/>
- 许可证文本：
  - `licenses/rust-LICENSE-MIT.txt`
  - `licenses/rust-LICENSE-APACHE.txt`
  - Windows 工具链内也保留了 `windows/rustup/toolchains/stable-x86_64-pc-windows-gnu/share/doc/rust/licenses/`
  - Linux 组件安装后位于 `<prefix>/share/doc/rust/`

Linux 包包含以下官方组件：

- rustc
- cargo
- rust-std
- rustfmt
- clippy
- rust-analyzer
- rust-src

## rustup

- 项目：rust-lang/rustup
- 许可证：MIT OR Apache-2.0
- 来源：<https://github.com/rust-lang/rustup>
- 许可证文本：
  - `licenses/rustup-LICENSE-MIT.txt`
  - `licenses/rustup-LICENSE-APACHE.txt`
- Windows 包包含 rustup。
- Linux 包不包含 rustup。

## MinGW-w64（仅 Windows 包）

- 项目：MinGW-w64
- 许可证：以 Zope Public License 2.1 为主；部分文件为 Public Domain / BSD / LGPL，
  详见上游 COPYING。
- 来源：<https://www.mingw-w64.org/>
- 许可证文本：`licenses/mingw-w64-COPYING.txt`

## GCC / G++ / GDB / GNU 工具（仅 Windows 包）

- 项目：GNU Compiler Collection、GNU Debugger、GNU Binutils、GNU Make 等
- 许可证：GPLv3 或更高版本；GCC 运行时库适用 GCC Runtime Library Exception。
- 来源：通过 WinLibs personal build 提供
  <https://winlibs.com/>
- 许可证文本：
  - `licenses/GCC-COPYING3.txt`
  - `licenses/GCC-RUNTIME-EXCEPTION.txt`
- Linux 包不包含这些工具。
- Linux 系统从发行版仓库安装 `gcc`、`gcc-c++` 和 `make`，并适用各自的系统许可证。

## WinLibs 附带的其他工具（仅 Windows 包）

WinLibs 压缩包还包含 CMake、Ninja、ccache、Python、Doxygen、Cppcheck、
Universal Ctags、NASM/Yasm 等工具，它们分别使用各自的开源许可证。
本包未修改这些文件，完整版本信息见：

- `windows/toolchain/mingw64/version_info.txt`
- WinLibs: <https://winlibs.com/>

如需严格合规地再分发整个包，请同时查阅各上游项目的许可证，并保留本说明
以及 `shared/licenses/` 和工具链自带的许可证文件。
