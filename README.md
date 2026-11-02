# 跨平台 Rust 开发环境

Windows 使用便携包。
Linux 使用离线安装包。
平台无关文件放在 `shared/`。

项目版本号使用 Rust 版本号。
当前版本为 `1.99.1`。

同一 Rust 版本的修订包使用标签 `v<version>-r<N>`，例如 `v1.99.1-r2`。
修订包文件名包含 `-r<N>`，例如 `-r2`。

## 下载与安装（Release）

普通用户不需要克隆仓库。
请从 GitHub Release 下载对应平台的压缩包。

1. 打开 <https://github.com/HasonHuang/rust-portable/releases/latest>。
2. 下载对应平台的资产和同一 Release 的 `SHA256SUMS`。

| 平台 | 资产 |
| --- | --- |
| Windows 10/11 x64 | `rust-portable-v<version>[-r<N>]-windows-x64.zip` |
| Linux x64（RHEL 系） | `rust-portable-v<version>[-r<N>]-linux-x64.tar.gz` |

3. 校验压缩包。
4. 解压。压缩包内有一个 `rust-portable/` 目录。
5. 按平台安装。

Windows：

1. 运行 `windows\configure-env.bat`。
2. 重新打开终端。
3. 运行 `windows\doctor.bat`。

Linux：

1. 安装系统依赖：`sudo dnf install -y gcc gcc-c++ make tar xz`。
2. 系统级安装：`sudo linux/install.sh`。
3. 或用户级安装：`linux/install.sh`。
4. 打开新终端，或执行 `. <前缀>/share/rust-portable/env.sh`。
5. 运行 `<前缀>/share/rust-portable/doctor.sh`。

校验示例：

Windows：

```bat
certutil -hashfile rust-portable-v1.99.1-windows-x64.zip SHA256
```

Linux：

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

Windows 解压路径和 Linux 安装前缀都不能包含空格。
`BUILD-INFO.txt` 记录版本、构建时间、Rust 版本和平台信息。

## 1. 平台支持与目录

| 平台 | 目录 | 状态 | 内容 |
| --- | --- | --- | --- |
| Windows 10/11 x64 | `windows/` | 可用 | Rust 1.99.1、MinGW-w64 GCC 16.2.0、启动脚本 |
| Linux x64（RHEL 系） | `linux/` | 可用 | Rust 1.99.1 官方组件离线安装包、安装脚本 |
| 平台无关 | `shared/` | 可用 | 示例、C 测试源码、许可证、版本文档 |

Linux 包不包含 GCC、g++ 或 make。
Linux 系统从发行版仓库安装这些依赖。

```text
rust-portable/
├─ README.md
├─ windows/
│  ├─ cargo/
│  ├─ rustup/
│  ├─ toolchain/mingw64/
│  └─ configure-env.bat 等启动脚本
├─ linux/
│  ├─ install.sh
│  ├─ uninstall.sh
│  ├─ add-component.sh
│  ├─ env.sh
│  ├─ doctor.sh
│  ├─ README.md
│  └─ packages/          # 仅 Release 包包含
└─ shared/
   ├─ examples/hello/
   ├─ tests/smoke.c
   ├─ licenses/
   ├─ VERSIONS.md
   └─ THIRD-PARTY-NOTICES.md
```

平台目录相互独立。
Windows 工具链是 PE 二进制，不能在 Linux 上运行。
Linux 工具链是 ELF 二进制，不能在 Windows 上运行。
`shared/` 只放平台无关的文件。

## 2. Windows 平台

Windows 使用便携包。
目标电脑不需要安装 Rust、Visual Studio 或 MinGW。

### 2.1 前置条件

- 系统：Windows 10 或 Windows 11，x64。
- 路径：不能包含空格。推荐短英文路径，例如 `D:\rust-portable`。
- 权限：运行 `configure-env.bat` 不需要管理员权限。

> 路径限制来自 WinLibs MinGW GCC。GCC 在含空格的路径下不能正确调用链接器。

### 2.2 安装

1. 拷贝整个 `rust-portable` 目录到目标位置。
2. 打开 `windows` 目录。
3. 双击 `configure-env.bat`。
4. 关闭所有终端、VS Code 和 JetBrains IDE。
5. 重新打开一个终端。
6. 检查版本：

```bat
rustc --version
cargo --version
gcc --version
```

7. 运行自检：

```bat
cd /d D:\rust-portable
windows\doctor.bat
```

`configure-env.bat` 只写当前用户的 `HKCU\Environment`。
它不写系统级环境变量，也不需要管理员权限。

移动目录后，请在新位置重新运行 `configure-env.bat`。

### 2.3 临时使用

- 双击 `windows\open-shell.bat`。
- 或在已有 cmd 中运行：

```bat
call "D:\rust-portable\windows\env.bat"
```

- 或在 PowerShell 中运行：

```powershell
. "D:\rust-portable\windows\env.ps1"
```

> 不要直接双击 `env.bat`。批处理进程退出后，环境变量会消失。

### 2.4 验证

```bat
cd /d D:\rust-portable
windows\doctor.bat
cargo run --manifest-path shared\examples\hello\Cargo.toml
```

预期输出：

```text
Hello from the portable Rust environment!
Toolchain: windows / x86_64
```

`where rustc` 必须指向本包的 `windows\cargo\bin\rustc.exe`。

### 2.5 更新 Rust

```bat
call "D:\rust-portable\windows\env.bat"
rustup update
```

需要离线标准库文档或 LLVM 工具时：

```bat
rustup component add rust-docs
rustup component add llvm-tools
```

Cargo 子命令会安装到本包内：

```bat
cargo install cargo-watch
```

## 3. Linux 平台

Linux 使用离线安装包。
它不使用 rustup。
它把 Rust 组件安装到独立前缀。
组件安装和自检不需要网络。

### 3.1 适用平台

- Linux x64（`x86_64`）。
- RHEL 系发行版：RHEL、CentOS、Rocky、AlmaLinux、Oracle Linux、openEuler、麒麟。
- glibc 2.17 或更新。
- kernel 3.2 或更新。
- 验证环境：Oracle Linux 8.10（离线安装和组件运行）。

### 3.2 前置条件

安装 Rust 不需要 C 编译器。
编译 Rust 程序需要 gcc、g++ 和 make。

```bash
sudo dnf install -y gcc gcc-c++ make tar xz
```

旧系统可以使用 `yum`。
`linux/install.sh --install-deps` 可以自动安装这些依赖。
Linux 安装前缀不能包含空格。

### 3.3 安装

```bash
tar -xzf rust-portable-v1.99.1-linux-x64.tar.gz
cd rust-portable
```

系统级安装：

```bash
sudo linux/install.sh
```

默认前缀：`/opt/rust-portable`。

用户级安装：

```bash
linux/install.sh
```

默认前缀：`~/.local/rust-portable`。

安装参数：

| 参数 | 说明 |
| --- | --- |
| `--prefix DIR` | 指定安装目录 |
| `--no-path` | 不修改 shell 配置 |
| `--install-deps` | 用 dnf/yum 安装 gcc、g++、make、tar、xz |
| `--force` | 允许非空前缀或不同版本 |
| `--skip-doctor` | 安装后不运行自检 |

### 3.4 激活环境

系统级安装写入 `/etc/profile.d/rust-portable.sh`。
用户级安装写入 `~/.bashrc` 和 `~/.bash_profile`；zsh 写入 `~/.zshrc`。

打开新终端即可生效。
当前终端可以手动激活：

```bash
. /opt/rust-portable/share/rust-portable/env.sh
```

用户级安装：

```bash
. "$HOME/.local/rust-portable/share/rust-portable/env.sh"
```

`env.sh` 可以重复执行，不会重复添加 PATH。

### 3.5 自检与示例

```bash
/opt/rust-portable/share/rust-portable/doctor.sh
cargo run --manifest-path /opt/rust-portable/share/rust-portable/shared/examples/hello/Cargo.toml
```

预期输出：

```text
Hello from the portable Rust environment!
Toolchain: linux / x86_64
```

`doctor.sh` 检查 rustc、cargo、rustfmt、clippy、rust-analyzer、gcc、g++ 和 make。
它还会离线编译并运行临时 Rust 项目和 C 测试程序。

### 3.6 组件

安装包包含：

- rustc
- cargo
- rust-std
- rustfmt
- clippy
- rust-analyzer
- rust-src

安装包不包含 `rust-docs`、`llvm-tools`、`rust-analysis` 和 `rustc-dev`。
需要补装组件时运行：

```bash
sudo /opt/rust-portable/share/rust-portable/add-component.sh \
  --sha256 <官方SHA256> \
  rust-docs-1.99.1-x86_64-unknown-linux-gnu.tar.xz
```

补装组件不改变 Rust 版本。

### 3.7 升级与卸载

安装新的 Rust 版本：

```bash
sudo linux/install.sh --prefix /opt/rust-portable --force
```

同一 Rust 版本新增组件时，直接重跑新的安装包：

```bash
sudo linux/install.sh --prefix /opt/rust-portable
```

卸载：

```bash
sudo /opt/rust-portable/share/rust-portable/uninstall.sh --yes
```

卸载脚本删除安装前缀和 shell 配置块。
它保留 `~/.cargo`。

### 3.8 离线说明

工具链安装和自检不需要网络。
第三方 crate 仍需要来源。

可选方案：

- 内网 Cargo 镜像。
- `cargo vendor` 目录。
- 预下载的 crate 缓存。

完全离线构建时设置：

```bash
export CARGO_NET_OFFLINE=true
```

## 4. 常见问题

**`rustc` 不是内部或外部命令（Windows）**

重新运行 `windows\configure-env.bat`。
关闭并重开终端。
运行 `windows\doctor.bat` 查看详细错误。

**提示找不到 link.exe 或 msvc（Windows）**

本包使用 `x86_64-pc-windows-gnu` 目标。
确认没有设置 `RUSTUP_TOOLCHAIN`、`RUSTFLAGS` 或项目配置来强制 MSVC。
运行 `rustup show` 查看当前工具链。

**路径含空格**

Windows 包路径和 Linux 安装前缀都不支持空格。
Windows 请移动整个包到无空格路径，并重新运行 `windows\configure-env.bat`。
Linux 请使用不含空格的前缀。

**Cargo 下载很慢**

工具链可以离线使用。
第三方 crate 仍需联网下载。
Windows 缓存位于 `windows\cargo\registry`。
Linux 缓存位于 `~/.cargo/registry`。

**VS Code 或 CLion 找不到 rust-analyzer（Windows）**

先运行 `windows\configure-env.bat`。
完全退出并重启 IDE。
也可以手动指定 `windows\cargo\bin\rust-analyzer.exe`。

**能否完全离线使用？**

可以编译纯标准库项目。
包含第三方依赖的项目需要预下载 crate，或使用 vendor 目录。

**支持 32 位、ARM64 或 Windows 7 吗？**

不支持。
Windows 版适用于 Windows 10/11 x64。

**支持 Linux 吗？**

支持 Linux x64。
支持 RHEL 系发行版，glibc 2.17 或更新。
验证环境为 Oracle Linux 8.10。
不支持 ARM64、i686 或 musl。

**Linux 包包含 GCC 吗？**

不包含。
请用系统包管理器安装：

```bash
sudo dnf install -y gcc gcc-c++ make
```

**Linux 包包含文档吗？**

不包含。
需要时用 `add-component.sh` 补装 `rust-docs`。

**Linux 包使用 rustup 吗？**

不使用。
它安装 Rust 官方独立组件。
升级时安装新的发布包。

**支持 macOS 吗？**

当前不支持。
包内没有 macOS 目录。

**包有多大？**

Windows 包解压后约 2.1 GB。
Linux 安装后约 1.3 GB。
Linux 离线安装包约 143 MB。

## 5. 版本与许可

- 版本、下载地址、SHA256：`shared/VERSIONS.md`
- 第三方许可说明：`shared/THIRD-PARTY-NOTICES.md`
- 许可证文本：`shared/licenses/`

Rust、Cargo、rustup 使用 MIT OR Apache-2.0。
MinGW-w64、GCC 和 WinLibs 组件使用各自的许可证。
Linux 包只分发 Rust 官方组件。
Linux 包不包含 GCC；GCC 由目标系统的软件仓库提供。

维护者发布流程见 `docs/RELEASING.md`。
