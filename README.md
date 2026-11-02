# 跨平台便携式 Rust 开发环境

本项目提供便携式 Rust 开发环境。
项目按平台划分目录。
一个包可以包含多个平台的工具链。
平台无关的文件放在 `shared/` 目录。

当前已包含 Windows x64 工具链。
Linux 工具链尚未包含。`linux/` 目录已预留。

项目版本号使用 Rust 版本号。
当前项目版本为 `1.99.1`。

## 下载与安装（Release）

普通用户不需要克隆仓库。
请从 GitHub Release 下载对应平台的压缩包。

1. 打开 <https://github.com/HasonHuang/rust-portable/releases/latest>。
2. 下载对应平台的资产：

| 平台 | 资产 |
| --- | --- |
| Windows 10/11 x64 | `rust-portable-v<version>-windows-x64.zip` |

3. 下载同一 Release 的 `SHA256SUMS`。
4. 校验压缩包。
5. 解压。压缩包内有一个 `rust-portable/` 目录。
6. Windows：运行 `windows\configure-env.bat`。
7. 重新打开终端。
8. 运行 `windows\doctor.bat` 完成自检。

Windows 校验示例：

```bat
certutil -hashfile rust-portable-v1.99.1-windows-x64.zip SHA256
```

Windows 解压路径不能包含空格。
Release 压缩包只包含当前平台的目录和 `shared/`。
`BUILD-INFO.txt` 记录版本、构建时间、Rust 版本和 MinGW 版本。

## 1. 平台支持与目录

### 1.1 平台状态

| 平台 | 目录 | 状态 | 内容 |
| --- | --- | --- | --- |
| Windows 10/11 x64 | `windows/` | 可用 | Rust 1.99.1、MinGW-w64 GCC 16.2.0、启动脚本 |
| Linux x64 | `linux/` | 计划中 | 尚未包含工具链 |
| 平台无关 | `shared/` | 可用 | 示例、C 测试源码、许可证、版本文档 |

平台目录相互独立。
Windows 工具链是 PE 二进制，不能在 Linux 上运行。
Linux 工具链加入后，也不能在 Windows 上运行。
`shared/` 只放平台无关的文件。

只使用 Windows 时，可以只复制 `windows/`、`shared/` 和 `README.md`。
只使用 Linux 时，可以只复制 `linux/`、`shared/` 和 `README.md`。
两个目录都保留时，一个包可以同时服务两个平台。

### 1.2 目录结构

```text
rust-portable/
├─ README.md
├─ windows/
│  ├─ bootstrap/rustup-init.exe
│  ├─ cargo/
│  ├─ rustup/
│  ├─ toolchain/mingw64/
│  ├─ scripts/install-env.ps1
│  ├─ env.bat
│  ├─ env.ps1
│  ├─ configure-env.bat
│  ├─ remove-env.bat
│  ├─ open-shell.bat
│  └─ doctor.bat
├─ linux/
│  └─ README.md
└─ shared/
   ├─ examples/hello/
   ├─ tests/smoke.c
   ├─ licenses/
   ├─ VERSIONS.md
   └─ THIRD-PARTY-NOTICES.md
```

`shared/` 是共享目录。
它不包含平台工具链。
Windows 脚本直接使用其中的示例和 C 测试源码。
Linux 脚本加入后也会使用同一批文件。
修改示例时，各平台脚本同时生效。

## 2. Windows 平台

Windows x64 的完整工具链已安装。
目标电脑不需要安装 Rust、Visual Studio 或 MinGW。

### 2.1 快速开始

#### 2.1.1 前置条件

- 系统：Windows 10 或 Windows 11，x64。
- 路径：不能包含空格。推荐短英文路径，例如 `D:\rust-portable`。
- 权限：运行 `configure-env.bat` 不需要管理员权限。

> 路径限制来自 WinLibs MinGW GCC。GCC 在含空格的路径下不能正确调用链接器。
> 启动脚本会检测空格并报错。

#### 2.1.2 永久启用（推荐）

1. 拷贝整个 `rust-portable` 目录到目标位置。
2. 打开 `windows` 目录。
3. 双击 `configure-env.bat`。
4. 关闭所有终端、VS Code 和 JetBrains IDE。
5. 重新打开一个终端。
6. 运行版本检查：

```bat
rustc --version
cargo --version
gcc --version
```

7. 运行完整自检：

```bat
cd /d D:\rust-portable
windows\doctor.bat
```

`configure-env.bat` 只写当前用户的 `HKCU\Environment`。
它设置 4 个用户环境变量，并修改用户 PATH。
它不写系统级环境变量。

#### 2.1.3 临时启用（不修改用户环境变量）

- 双击 `windows\open-shell.bat`。
- 或指定工作目录：`windows\open-shell.bat D:\work\myproject`
- 或在已有 cmd 中运行：

```bat
call "D:\rust-portable\windows\env.bat"
```

- 或在 PowerShell 中运行（注意前面的点）：

```powershell
. "D:\rust-portable\windows\env.ps1"
```

> 不要直接双击 `env.bat`。批处理进程退出后，环境变量会消失。
> 请使用 `open-shell.bat`，或在已有终端里 `call` 它。

#### 2.1.4 验证环境

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

手动检查：

```bat
set CARGO_HOME
set RUSTUP_HOME
where rustc
where gcc
rustup show
```

`where rustc` 必须指向本包的 `windows\cargo\bin\rustc.exe`。

### 2.2 手动安装

本包已经安装 Windows 工具链。
通常的“手动安装”指手动设置环境变量。
只有工具链缺失或损坏时，才需要重新安装工具链。

#### 2.2.1 手动设置永久环境变量（图形界面）

1. 打开“编辑账户的环境变量”。
2. 新建以下用户变量：

| 变量 | 值 |
| --- | --- |
| `RUST_PORTABLE_HOME` | `D:\rust-portable` |
| `CARGO_HOME` | `D:\rust-portable\windows\cargo` |
| `RUSTUP_HOME` | `D:\rust-portable\windows\rustup` |
| `MINGW_HOME` | `D:\rust-portable\windows\toolchain\mingw64` |

3. 编辑用户变量 `Path`。
4. 在列表最前面加入这两项：

```text
D:\rust-portable\windows\cargo\bin
D:\rust-portable\windows\toolchain\mingw64\bin
```

5. 点击“确定”。
6. 关闭并重新打开终端。

> 不要用 `setx PATH "%PATH%;..."` 修改 PATH。该命令可能截断 PATH。
> 请用图形界面，或使用 `configure-env.bat`。

#### 2.2.2 手动设置当前终端（临时）

在 cmd 中运行：

```bat
set "RUST_PORTABLE_HOME=D:\rust-portable"
set "CARGO_HOME=%RUST_PORTABLE_HOME%\windows\cargo"
set "RUSTUP_HOME=%RUST_PORTABLE_HOME%\windows\rustup"
set "MINGW_HOME=%RUST_PORTABLE_HOME%\windows\toolchain\mingw64"
set "PATH=%CARGO_HOME%\bin;%MINGW_HOME%\bin;%PATH%"
```

这些变量只在当前窗口有效。
运行 `env.bat` 可以完成同样的设置。

#### 2.2.3 手动验证

```bat
where rustc
where cargo
where gcc
rustc --version
cargo --version
gcc --version
```

`where rustc` 必须显示本包中的路径。

#### 2.2.4 手动重新安装工具链（可选）

正常使用不需要本节。仅当工具链缺失或损坏时执行。

1. 先打开一个新的 cmd。
2. 设置本地目录：

```bat
set "CARGO_HOME=D:\rust-portable\windows\cargo"
set "RUSTUP_HOME=D:\rust-portable\windows\rustup"
```

3. 运行 rustup 安装器：

```bat
D:\rust-portable\windows\bootstrap\rustup-init.exe -y --no-modify-path --profile minimal --default-host x86_64-pc-windows-gnu --default-toolchain stable-x86_64-pc-windows-gnu
```

4. 添加常用组件：

```bat
D:\rust-portable\windows\cargo\bin\rustup.exe component add rustfmt clippy rust-analyzer rust-src
```

5. 运行自检：

```bat
D:\rust-portable\windows\doctor.bat
```

注意：本节需要联网下载。工具链会安装到本包目录，不会安装到用户主目录。

#### 2.2.5 手动卸载环境

1. 打开“编辑账户的环境变量”。
2. 删除 `CARGO_HOME`、`RUSTUP_HOME`、`MINGW_HOME`、`RUST_PORTABLE_HOME`。
3. 从用户 `Path` 中删除本包的两个路径。
4. 重新打开终端。
5. 删除整个 `rust-portable` 目录。

也可以先运行 `windows\remove-env.bat`。该脚本只删除环境变量，不删除文件。

### 2.3 `rustup-init.exe` 是什么？

`rust-init.exe` 不是正确文件名。正确文件名是 `rustup-init.exe`。
文件位置：`windows\bootstrap\rustup-init.exe`。

**作用**

它是 rustup 的官方安装引导程序。
它安装 rustup、cargo 和 Rust 工具链。
它把文件写入 `CARGO_HOME` 和 `RUSTUP_HOME` 指向的目录。

**需要执行安装吗？**

不需要。
本包已经安装 Rust 1.99.1 工具链。
正常开发不需要运行它。

**正常流程会执行它吗？**

不会。
随包脚本不会调用它。
`windows\bootstrap` 不在 PATH 中。
正常构建、更新、复制和移动目录都不会执行它。

只有以下情况会执行它：

1. 你手动双击或运行它。
2. 你按 2.2.4 节修复或重建工具链。
3. 外部脚本显式调用这个路径。

本包制作时运行过一次，用来安装工具链。现在不需要再次运行。

**它和 `rustup.exe` 有什么区别？**

`windows\bootstrap\rustup-init.exe` 是一次性安装引导器。
`windows\cargo\bin\rustup.exe` 是日常使用的 rustup 运行时。
`cargo.exe`、`rustc.exe`、`rustfmt.exe` 等是 rustup 的代理程序。
原始包中，它们是指向 `rustup.exe` 的硬链接。
你运行 `cargo` 或 `rustc` 时，执行的是代理，不是 `rustup-init.exe`。
`rustup update` 和 `rustup self update` 只使用 `rustup.exe`。

**为什么保留它？**

用于修复或重建本包内的工具链。
也用于重新安装。

**可以直接双击吗？**

不要。
直接双击时，它可能使用 `%USERPROFILE%\.cargo` 和 `%USERPROFILE%\.rustup`。
它也可能修改 PATH。
这样会生成包外的第二套 Rust。

需要重建时，请按 2.2.4 节执行。
执行前必须设置本地 `CARGO_HOME` 和 `RUSTUP_HOME`。

**安装完成后用什么？**

安装完成后，使用 `rustup`。
示例：

```bat
rustup update
rustup component add rust-docs
rustup show
```

`rustup-init.exe` 只负责首次安装。
它不参与日常构建。

**可以删除吗？**

可以。
删除 `windows\bootstrap\rustup-init.exe` 不影响现有工具链。
但删除后不能再用它重新安装。

### 2.4 更新 Rust

```bat
call "D:\rust-portable\windows\env.bat"
rustup update
```

本包使用 `minimal` profile，以控制体积。
需要离线标准库文档或 LLVM 工具时执行：

```bat
rustup component add rust-docs
rustup component add llvm-tools
```

Cargo 子命令会安装到本包内：

```bat
cargo install cargo-watch
```

### 2.5 移动目录与旧版升级

#### 2.5.1 移动目录

1. 关闭所有终端和 IDE。
2. 拷贝完整目录。
3. 在新位置运行 `windows\configure-env.bat`。
4. 重新打开终端。

脚本会删除旧位置的 PATH 项，再写入新位置。
Windows 至少需要 `windows/`、`shared/` 和 `README.md`。
`linux/` 可以保留，也可以删除。

#### 2.5.2 旧版平铺布局

旧版把 `cargo`、`rustup`、`toolchain` 放在包根目录。
新版改为 `windows/` 子目录。
在新版目录中运行一次 `windows\configure-env.bat`。
脚本会清理旧版遗留的 PATH 项。

#### 2.5.3 多个副本

Windows 用户环境变量只能指向一个副本。
需要同时使用多个副本时，请使用各副本的 `windows\open-shell.bat`。
不要对多个副本反复运行 `configure-env.bat`。

## 3. Linux 平台（计划中）

### 3.1 当前状态

当前包不包含 Linux 工具链。
`linux/` 目录只有说明文件。
不要在 Linux 上运行 `windows/` 中的二进制文件。

### 3.2 计划中的目录

```text
linux/
├─ cargo/
├─ rustup/
├─ env.sh
├─ setup.sh
└─ doctor.sh
```

### 3.3 计划中的行为

Linux 支持加入后，计划提供：

- `linux/env.sh`：在当前 shell 中激活环境。
- `linux/setup.sh`：写入用户的 shell 配置。
- `linux/doctor.sh`：检查工具链和 C 编译器。
- 工具链安装在 `linux/` 内，不写入 `$HOME/.cargo` 或 `$HOME/.rustup`。
- `shared/` 中的示例和 C 测试源码继续共用。

这些文件尚未提供。
不要按上述名称执行命令。
Linux 支持加入后，本文会补充安装步骤和验证方法。

## 4. 常见问题

**`rustc` 不是内部或外部命令（Windows）**

重新运行 `windows\configure-env.bat`。
关闭并重开终端。
运行 `windows\doctor.bat` 查看详细错误。

**提示找不到 link.exe 或 msvc（Windows）**

本包使用 `x86_64-pc-windows-gnu` 目标。
确认没有设置 `RUSTUP_TOOLCHAIN`、`RUSTFLAGS` 或项目配置来强制 MSVC。
运行 `rustup show` 查看当前工具链。

**路径含空格（Windows）**

不支持。
把整个包移动到无空格路径。
重新运行 `windows\configure-env.bat`。

**Cargo 下载很慢**

工具链可以离线使用。
第三方 crate 仍需联网下载。
下载缓存位于 `windows\cargo\registry`，会随包拷贝。

**VS Code 或 CLion 找不到 rust-analyzer（Windows）**

先运行 `windows\configure-env.bat`。
完全退出并重启 IDE。
也可以手动指定 `windows\cargo\bin\rust-analyzer.exe`。

**能否完全离线使用？**

可以编译纯标准库项目。
包含第三方依赖的项目需要预下载 crate，或使用 vendor 目录。

**支持 32 位、ARM64 或 Windows 7 吗？**

不支持。
Windows 版是 x64 版本，适用于 Windows 10/11 x64。

**支持 Linux 吗？**

支持正在计划中。
当前包只包含 Windows 工具链。
`linux/` 目录已预留，但没有工具链和脚本。
Windows 工具链不能在 Linux 上运行。

**支持 macOS 吗？**

当前不支持。
包内没有 macOS 目录。
后续是否加入尚未确定。

**包有多大？**

当前 Windows 包约 2.1 GB。
Linux 工具链加入后，包会更大。
可以按平台只复制需要的目录。

## 5. 版本与许可

- Windows 版本、下载地址、SHA256：`shared/VERSIONS.md`
- 第三方许可说明：`shared/THIRD-PARTY-NOTICES.md`
- 许可证文本：`shared/licenses/`

Rust、Cargo、rustup 使用 MIT OR Apache-2.0。
MinGW-w64、GCC 和 WinLibs 组件使用各自的许可证。

Linux 工具链尚未包含。
Linux 支持加入后，版本和许可信息也会记录在 `shared/VERSIONS.md`。

## 6. 发布方式（维护者）

发布版本号使用 Rust 版本号。
版本保存在仓库根目录的 `VERSION`，Release 标签固定为 `v<VERSION>`。
构建脚本会校验打包的 `rustc --version` 必须等于 `VERSION`，不一致时构建失败。

### 6.1 发布前准备

1. 把 `VERSION` 更新为要发布的 Rust 版本，例如 `1.99.1`。
2. 更新 `CHANGELOG.md`。
3. 工具链版本变化时更新 `shared/VERSIONS.md`。
4. 可选：新增 `docs/release-notes/v<version>.md` 作为 Release Notes。
   没有该文件时，GitHub 自动生成发布说明。
5. 提交并推送到 `main`：

```bash
git add VERSION CHANGELOG.md shared/VERSIONS.md docs/release-notes/
git commit -m "Release v1.99.1"
git push origin main
```

### 6.2 方式一：推送标签（自动构建并发布）

```bash
git tag -a v1.99.1 -m "rust-portable v1.99.1"
git push origin v1.99.1
```

标签必须等于 `v<VERSION>`，否则工作流在第一步失败。

### 6.3 方式二：手动运行工作流

在 GitHub 上打开 Actions → `Release` → `Run workflow`。

- 版本从 `VERSION` 读取，不需要再输入版本号。
- 工作流会在所选提交上创建 `v<VERSION>` 标签。
- 可选 `draft` 输入：只生成草稿 Release，不直接公开。
- 可选 `dry_run` 输入：只构建并上传 Actions artifact，不创建标签或 Release。
- 如果该版本的 Release 已经发布，工作流会拒绝重复构建。
  发布新版本请先更新 `VERSION`。

`dry_run` 用于在正式切换前验证工作流。
例如 `v1.99.1` 已经手动发布，测试时勾选 `dry_run` 即可，不会产生版本冲突。
测试产物在对应 workflow run 页面的 Artifacts 中，保留 7 天。

### 6.4 工作流执行内容

工作流文件：`.github/workflows/release.yml`。

| 步骤 | 内容 |
| --- | --- |
| `resolve` | 读取 `VERSION`，校验标签格式和版本一致性，检查同版本 Release 是否已存在；`dry_run` 时跳过检查 |
| `build-windows` | 在 `windows-latest` 上安装同一版本的 Rust，构建 ZIP，运行自检，生成 `SHA256SUMS` |
| `publish` | 创建或复用 Release，上传 ZIP 和 `SHA256SUMS`，然后发布；`dry_run` 时跳过 |

工作流需要仓库 Settings → Actions → General → Workflow permissions 允许读写。
GitHub Release 单个资产不能超过 2 GiB。

### 6.5 本地构建（备用）

首次构建时，先准备工具链：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-windows.ps1
```

该脚本下载固定版本的 rustup-init.exe 和 WinLibs MinGW-w64，并校验 SHA256。
默认安装 `VERSION` 指定的 Rust 版本，也可以用 `-RustVersion 1.99.1` 指定。

然后运行打包脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

脚本执行以下动作：

- 从 `VERSION` 读取版本号。
- 把 `windows/` 和 `shared/` 复制到临时目录。
- 写入 `VERSION` 和 `BUILD-INFO.txt`。
- 校验 `rustc --version` 等于发布版本。
- 运行 `windows\doctor.bat --no-pause` 自检。
- 生成 `dist\rust-portable-v<version>-windows-x64.zip`。
- 生成 `dist\SHA256SUMS`。

需要 7-Zip。没有 7-Zip 时，脚本使用 Windows 10/11 自带的 `tar.exe`。
工具链目录不提交到 Git。

### 6.6 手动发布 GitHub Release（工作流不可用时）

需要 GitHub CLI 并已登录：

```bash
gh auth login
```

创建工作流对应的草稿 Release：

```bash
gh release create v1.99.1 \
  dist/rust-portable-v1.99.1-windows-x64.zip \
  dist/SHA256SUMS \
  --title "rust-portable v1.99.1" \
  --notes-file docs/release-notes/v1.99.1.md \
  --draft
```

检查资产后发布：

```bash
gh release edit v1.99.1 --draft=false
```

### 6.7 发布检查清单

- `VERSION` 等于实际打包的 `rustc --version`。
- Release 有 ZIP 和 `SHA256SUMS` 两个资产，文件名带正确版本号。
- `SHA256SUMS` 与下载的压缩包一致：

```bat
certutil -hashfile rust-portable-v1.99.1-windows-x64.zip SHA256
```

- 在干净目录解压后，`windows\doctor.bat` 全部通过。
- Release Notes 中的平台、工具链版本、安装步骤准确。
- 当前只发布 Windows x64；Linux 资产尚未提供。

更详细的维护者流程见仓库中的 `docs/RELEASING.md`。
