# 第三方组件许可说明

本便携包当前分发 Windows x64 的 Rust 工具链和 WinLibs MinGW-w64 构建。
Linux 工具链暂未包含。

各组件版权归其各自作者所有。本包未修改这些二进制文件。
许可证文本在 `shared/licenses/` 目录。

## Rust 工具链 / Cargo

- 项目：Rust Programming Language
- 许可证：MIT OR Apache-2.0
- 来源：<https://static.rust-lang.org/>
- 许可证文本：
  - `licenses/rust-LICENSE-MIT.txt`
  - `licenses/rust-LICENSE-APACHE.txt`
  - 工具链内也保留了 `windows/rustup/toolchains/stable-x86_64-pc-windows-gnu/share/doc/rust/licenses/`

## rustup

- 项目：rust-lang/rustup
- 许可证：MIT OR Apache-2.0
- 来源：<https://github.com/rust-lang/rustup>
- 许可证文本：
  - `licenses/rustup-LICENSE-MIT.txt`
  - `licenses/rustup-LICENSE-APACHE.txt`

## MinGW-w64

- 项目：MinGW-w64
- 许可证：以 Zope Public License 2.1 为主；部分文件为 Public Domain / BSD / LGPL，
  详见上游 COPYING。
- 来源：<https://www.mingw-w64.org/>
- 许可证文本：`licenses/mingw-w64-COPYING.txt`

## GCC / G++ / GDB / GNU 工具

- 项目：GNU Compiler Collection、GNU Debugger、GNU Binutils、GNU Make 等
- 许可证：GPLv3 或更高版本；GCC 运行时库适用 GCC Runtime Library Exception。
- 来源：通过 WinLibs personal build 提供
  <https://winlibs.com/>
- 许可证文本：
  - `licenses/GCC-COPYING3.txt`
  - `licenses/GCC-RUNTIME-EXCEPTION.txt`

## WinLibs 附带的其他工具

WinLibs 压缩包还包含 CMake、Ninja、ccache、Python、Doxygen、Cppcheck、
Universal Ctags、NASM/Yasm 等工具，它们分别使用各自的开源许可证。
本包未修改这些文件，完整版本信息见：

- `windows/toolchain/mingw64/version_info.txt`
- WinLibs: <https://winlibs.com/>

如需严格合规地再分发整个包，请同时查阅各上游项目的许可证，并保留本说明
以及 `shared/licenses/` 和工具链自带的许可证文件。
