# npm 安装与发布

## 1. 范围

npm 包只支持 Windows 10/11 x64。
Linux 用户请使用 Release 中的 `tar.gz` 安装包。

npm 发布是可选的人工操作。
npm 发布不属于 Release 流程。
维护者能单独执行 npm 发布，也能跳过。

本文分两部分：

1. 用户安装。
2. 维护者构建和发布。

本文示例使用版本 `1.99.1`。
按实际版本替换版本号。

本文描述从包含本修复的修订版开始的新布局，例如 `1.99.1-r2`。
`1.99.1` 及更早版本安装到 `%LOCALAPPDATA%\rust-portable\<version>`。
旧版迁移见第 3.6 节。

## 2. 包结构

npm 上的工具链分为 8 个包。

| 包 | 作用 | 内容 |
| --- | --- | --- |
| `@ihason/rust-portable` | 入口包 | `README.md`、`package.json` |
| `@ihason/rust-portable-win32-x64` | 平台包 | `install.js`、`archive.json`、`README.md` |
| `@ihason/rust-portable-win32-x64-chunk-01` 至 `-06` | 分片包 | 二进制文件 `part01` |

入口包用 `optionalDependencies` 依赖平台包。
平台包用 `dependencies` 依赖 6 个分片包。

分片包存放 Windows ZIP 的切片。
每个分片不超过 100 MiB。
分片包不能单独使用。

安装步骤如下：

1. npm 安装入口包、平台包和 6 个分片包。
2. npm 运行平台包的 `postinstall`。
3. `install.js` 拼接分片。
4. `install.js` 校验字节数和 SHA256。
5. `install.js` 用 `tar.exe` 解压工具链。
6. `install.js` 写入 `.installed` 标记。

安装器不访问网络。

## 3. 用户安装

### 3.1 要求

- Windows 10 1803 或更新版本，或 Windows 11。
- x64 架构。
- Node.js 18 或更新版本。
- npm 9 或更新版本。
- 至少 5 GB 可用磁盘空间。
- 安装路径不含空格。

检查平台和架构：

```powershell
node -p "process.platform + ' ' + process.arch"
```

输出必须是：

```text
win32 x64
```

不要使用 `ia32` 或 `arm64` 版本的 Node.js。
npm 静默跳过不匹配的平台包。

检查 `tar.exe`：

```powershell
Test-Path "$env:SystemRoot\System32\tar.exe"
```

输出必须是 `True`。

### 3.2 安装

#### 3.2.1 脚本安装（npm postinstall）

进入项目目录：

```powershell
cd D:\my-project
```

安装入口包：

```powershell
npm install @ihason/rust-portable
```

安装目录：

```text
<执行 npm install 的目录>\rust-portable
```

示例：

```text
D:\my-project\rust-portable
```

npm 在项目根目录执行时，工具链安装到项目内的 `rust-portable` 目录。
npm 在 workspace 根目录执行时，工具链安装到 workspace 根目录。

不要使用以下参数：

- `--omit=optional`
- `--no-optional`
- `--ignore-scripts`

平台包是 optional dependency。
`--omit=optional` 和 `--no-optional` 导致平台包或分片包不安装。
`--ignore-scripts` 导致 `postinstall` 不运行。

安装指定版本：

```powershell
npm install @ihason/rust-portable@1.99.1
```

不推荐全局安装。
必须全局安装时，先设置 `RUST_PORTABLE_INSTALL_DIR`：

```powershell
$env:RUST_PORTABLE_INSTALL_DIR = 'C:\rust-portable'
npm install --global @ihason/rust-portable
```

推荐项目级安装。
全局安装也会把约 604 MB 的分片留在全局 `node_modules`。

正常输出示例：

```text
[rust-portable] Adding @ihason/rust-portable-win32-x64-chunk-01/part01
...
[rust-portable] Verified rust-portable-v1.99.1-windows-x64.zip (611000377 bytes, SHA256 ...)
[rust-portable] Extracting to D:\my-project\.staging-...
[rust-portable] Installed to D:\my-project\rust-portable
```

修改安装目录：

```powershell
$env:RUST_PORTABLE_INSTALL_DIR = 'C:\rust-portable'
npm install @ihason/rust-portable
```

`RUST_PORTABLE_INSTALL_DIR` 是完整安装目录。
`RUST_PORTABLE_INSTALL_DIR` 必须不含空格。
默认安装目录也受项目路径限制：项目路径不能含空格。
`RUST_PORTABLE_INSTALL_DIR` 只用于选择安装目录，不是工具链运行变量。
`configure-env.bat` 不设置该变量。

安装目录已存在但版本不同或不完整时，强制替换：

```powershell
$env:RUST_PORTABLE_FORCE = '1'
npm install @ihason/rust-portable
```

#### 3.2.2 手工安装（手动运行 install.js）

这是故障恢复步骤，不是正常安装步骤。

npm 或 pnpm 阻止 `postinstall`，或安装器失败时，用手工安装。

1. 进入项目目录：

   ```powershell
   cd D:\my-project
   ```

2. 安装文件，不运行脚本：

   ```powershell
   npm install @ihason/rust-portable --include=optional --ignore-scripts
   ```

3. 运行安装器：

   ```powershell
   Remove-Item Env:RUST_PORTABLE_INSTALL_DIR -ErrorAction SilentlyContinue
   node node_modules\@ihason\rust-portable-win32-x64\install.js
   ```

`install.js` 使用 `INIT_CWD`。
没有 npm 环境变量时，使用当前目录。
从项目根目录运行可以保证安装到 `.\rust-portable`。

使用自定义安装目录时，设置完整目录，不要清空：

```powershell
$env:RUST_PORTABLE_INSTALL_DIR = 'C:\rust-portable'
node node_modules\@ihason\rust-portable-win32-x64\install.js
```

安装器输出解压目录。
环境配置见第 3.3 节。

本节的手工安装仍使用 npm 下载文件。
完全不用 npm 时，请使用 Release ZIP。

### 3.3 配置环境

环境配置有三种方式：

| 方式 | 写入位置 | 生效范围 | 适合场景 |
| --- | --- | --- | --- |
| 脚本配置 | 用户环境变量 | 新终端和 IDE | 默认，推荐 |
| 手工配置（临时） | 当前终端 | 当前终端 | 临时使用 |
| 手工配置（永久） | 用户环境变量 | 新终端和 IDE | 不能运行脚本 |

#### 3.3.1 脚本配置（configure-env.bat）

进入安装目录：

```powershell
cd D:\my-project\rust-portable
```

使用自定义安装目录时，进入该目录。

运行配置脚本：

```powershell
& ".\windows\configure-env.bat"
```

`configure-env.bat` 写入当前用户的 `HKCU\Environment`。
`configure-env.bat` 不需要管理员权限。

`configure-env.bat` 设置以下变量：

| 变量 | 值 |
| --- | --- |
| `RUST_PORTABLE_HOME` | 工具链根目录 |
| `CARGO_HOME` | `<root>\windows\cargo` |
| `RUSTUP_HOME` | `<root>\windows\rustup` |
| `MINGW_HOME` | `<root>\windows\toolchain\mingw64` |
| `PATH` | 在最前面加入 `<root>\windows\cargo\bin` 和 `<root>\windows\toolchain\mingw64\bin` |

`RUST_PORTABLE_HOME` 由 `configure-env.bat` 设置为工具链根目录。
`RUST_PORTABLE_INSTALL_DIR` 只用于安装，不是工具链运行变量。

关闭所有终端。
关闭 VS Code 和其他 IDE。
重新打开终端。

检查命令：

```powershell
rustc --version
cargo --version
gcc --version
```

运行自检：

```powershell
& "$env:RUST_PORTABLE_HOME\windows\doctor.bat"
```

#### 3.3.2 手工配置（env.ps1 或手工变量）

临时配置不写注册表。
永久配置写入用户环境变量。

**临时配置（当前终端）**

只在当前 PowerShell 终端生效：

```powershell
$root = "D:\my-project\rust-portable"
$env:RUST_PORTABLE_HOME = $root
$env:RUST_PORTABLE_WINDOWS_DIR = "$root\windows"
$env:RUST_PORTABLE_SHARED = "$root\shared"
$env:CARGO_HOME = "$root\windows\cargo"
$env:RUSTUP_HOME = "$root\windows\rustup"
$env:MINGW_HOME = "$root\windows\toolchain\mingw64"
$env:Path = "$root\windows\cargo\bin;$root\windows\toolchain\mingw64\bin;$env:Path"
```

也可以使用随包脚本：

```powershell
. "D:\my-project\rust-portable\windows\env.ps1"
```

cmd：

```bat
call "D:\my-project\rust-portable\windows\env.bat"
```

手工配置只影响当前终端。
新终端需要重新执行。
不要重复执行 PATH 赋值行。需要重复激活时，使用 `env.ps1` 或 `env.bat`。

**永久配置（用户环境变量）**

优先使用 `configure-env.bat`。
必须手工写入用户变量时，用 PowerShell：

```powershell
$root = "D:\my-project\rust-portable"
[Environment]::SetEnvironmentVariable('RUST_PORTABLE_HOME', $root, 'User')
[Environment]::SetEnvironmentVariable('RUST_PORTABLE_WINDOWS_DIR', "$root\windows", 'User')
[Environment]::SetEnvironmentVariable('RUST_PORTABLE_SHARED', "$root\shared", 'User')
[Environment]::SetEnvironmentVariable('CARGO_HOME', "$root\windows\cargo", 'User')
[Environment]::SetEnvironmentVariable('RUSTUP_HOME', "$root\windows\rustup", 'User')
[Environment]::SetEnvironmentVariable('MINGW_HOME', "$root\windows\toolchain\mingw64", 'User')
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', "$root\windows\cargo\bin;$root\windows\toolchain\mingw64\bin;$path", 'User')
```

注意：

- 不要重复执行 PATH 设置命令。重复执行会重复添加 PATH 项。
- `remove-env.bat` 只清理 `configure-env.bat` 写入的项。
- 手工写入的项需要手工删除。
- 手工永久配置不广播环境变更。新终端可能看不到变量，注销或重启后生效。
- 永久配置后，新终端中的检查命令与第 3.3.1 节相同。

### 3.4 验证

完成第 3.3.1 节或第 3.3.2 节后，检查 `rustc` 路径：

```powershell
where.exe rustc
```

运行示例：

```powershell
cargo run --manifest-path "$env:RUST_PORTABLE_HOME\shared\examples\hello\Cargo.toml"
```

预期输出：

```text
Hello from the portable Rust environment!
Toolchain: windows / x86_64
```

`where.exe rustc` 必须指向安装目录中的 `windows\cargo\bin\rustc.exe`。

### 3.5 配置 IDE

VS Code：

1. 完全退出 VS Code。
2. 重新打开 VS Code。
3. 检查终端中的 `rustc --version`。

如果 rust-analyzer 仍使用旧工具链，设置：

```text
rust-analyzer.server.path = <root>\windows\cargo\bin\rust-analyzer.exe
```

JetBrains IDE：

1. 完全退出 IDE。
2. 重新打开 IDE。
3. 在 Rust 工具链设置中选择 `<root>\windows\cargo`。

### 3.6 升级

升级会替换同一个安装目录。
新版本版本号与旧版本不同，安装器要求强制替换。

进入项目目录：

```powershell
cd D:\my-project
```

设置强制替换并安装新版本：

```powershell
$env:RUST_PORTABLE_FORCE = '1'
npm install @ihason/rust-portable@latest
```

如果使用自定义安装目录，设置 `RUST_PORTABLE_INSTALL_DIR`：

```powershell
$env:RUST_PORTABLE_INSTALL_DIR = 'C:\rust-portable'
$env:RUST_PORTABLE_FORCE = '1'
npm install @ihason/rust-portable@latest
```

安装器先解压新版本，再删除旧目录。
安装失败时，旧目录保持不变。

升级后重新运行配置脚本：

```powershell
cd D:\my-project\rust-portable
& ".\windows\configure-env.bat"
```

`npm update` 在版本不变时不重新运行 `postinstall`。
需要重新安装时，使用 `npm install`。

#### 从旧版 `%LOCALAPPDATA%` 布局迁移

旧版安装到 `%LOCALAPPDATA%\rust-portable\<version>`。
迁移步骤：

1. 运行旧目录的卸载脚本：

   ```powershell
   & "$env:LOCALAPPDATA\rust-portable\1.99.1\windows\remove-env.bat"
   ```

2. 删除旧目录：

   ```powershell
   Remove-Item "$env:LOCALAPPDATA\rust-portable\1.99.1" -Recurse -Force
   ```

3. 在新项目目录安装：

   ```powershell
   cd D:\my-project
   npm install @ihason/rust-portable
   ```

4. 运行新目录的配置脚本：

   ```powershell
   & "D:\my-project\rust-portable\windows\configure-env.bat"
   ```

### 3.7 卸载

运行卸载脚本：

```powershell
& "D:\my-project\rust-portable\windows\remove-env.bat"
```

重新打开终端。

删除安装目录：

```powershell
Remove-Item "D:\my-project\rust-portable" -Recurse -Force
```

使用自定义安装目录时，替换上述路径。

删除项目中的分片：

```powershell
Remove-Item node_modules\@ihason -Recurse -Force
```

分片约占 604 MB。

## 4. 故障排查

### 4.1 只安装入口包

症状：

- `node_modules\@ihason` 下只有 `rust-portable`。
- 平台包和 6 个分片包不存在。
- `npm install` 的退出码为 0。

原因：平台包是 optional dependency。
optional 依赖子树中的任何一步失败，npm 都静默丢弃整个子树。

常见原因：

| 原因 | 检查项 |
| --- | --- |
| 省略 optional 依赖 | `omit=optional`、`--no-optional` |
| 路径含空格 | 项目路径或 `RUST_PORTABLE_INSTALL_DIR` |
| Node 架构不匹配 | `ia32`、`arm64`、非 Windows |
| 磁盘空间不足 | 至少 5 GB |
| `tar.exe` 不可用 | Windows 版本过旧 |
| postinstall 未运行 | `--ignore-scripts`、pnpm 脚本策略 |

诊断命令：

```powershell
node -p "process.platform + ' ' + process.arch"
npm config get omit
npm config get optional
npm ls @ihason/rust-portable --all
echo $env:RUST_PORTABLE_INSTALL_DIR
echo $env:RUST_PORTABLE_HOME
echo $env:INIT_CWD
```

正常结果：

- 平台和架构为 `win32 x64`。
- `omit` 为空。
- `npm ls` 显示平台包和 6 个分片包。

默认安装目录是：

```text
<INIT_CWD>\rust-portable
```

重新安装：

```powershell
npm install @ihason/rust-portable --include=optional
```

如果仍然只安装入口包，先安装文件，再手动运行安装器：

```powershell
npm install @ihason/rust-portable --include=optional --ignore-scripts
node node_modules\@ihason\rust-portable-win32-x64\install.js
```

npm 隐藏 optional 依赖的失败输出。
手动运行安装器显示真实错误。

常见错误：

```text
[rust-portable] Install path contains spaces: ...
[rust-portable] Unsupported platform ...
[rust-portable] Windows tar.exe was not found ...
[rust-portable] Missing data chunk: ...
[rust-portable] Archive verification failed ...
```

### 4.2 安装路径含空格

默认安装目录是项目内的 `rust-portable`。
项目路径含空格时，安装失败。

设置无空格安装目录：

```powershell
$env:RUST_PORTABLE_INSTALL_DIR = 'C:\rust-portable'
npm install @ihason/rust-portable --include=optional
```

`RUST_PORTABLE_INSTALL_DIR` 是完整安装目录。

运行配置脚本：

```powershell
& "C:\rust-portable\windows\configure-env.bat"
```

### 4.3 安装目录已存在

症状：

```text
[rust-portable] Destination already contains rust-portable 1.99.0: D:\my-project\rust-portable
Remove it, or set RUST_PORTABLE_FORCE=1 to replace it.
```

原因：

- 同名目录已存在。
- 目录版本与当前 npm 包版本不同。
- 目录不完整。

处理步骤：

1. 删除旧目录：

   ```powershell
   Remove-Item D:\my-project\rust-portable -Recurse -Force
   ```

2. 重新安装：

   ```powershell
   npm install @ihason/rust-portable
   ```

也可以强制替换：

```powershell
$env:RUST_PORTABLE_FORCE = '1'
npm install @ihason/rust-portable
```

如果 `RUST_PORTABLE_INSTALL_DIR` 指向旧目录，先清除它：

```powershell
Remove-Item Env:RUST_PORTABLE_INSTALL_DIR -ErrorAction SilentlyContinue
```

如果出现以下错误，说明目标目录不是 rust-portable 安装目录：

```text
[rust-portable] Destination is not a rust-portable install: ...
Choose another RUST_PORTABLE_INSTALL_DIR.
```

处理：把 `RUST_PORTABLE_INSTALL_DIR` 指向专用目录，例如 `C:\rust-portable`。
不要指向项目根目录。

### 4.4 包看起来为空

这是正常现象：

- 入口包约 1 KB。
- 平台包约 8 KB。
- 分片包不超过 100 MiB。
- 最后一个分片包约 82.7 MB。
- 分片包只有一个无扩展名的 `part01`。

npm 网页不预览二进制文件。
分片包页面看起来没有内容。

检查实际大小：

```powershell
Get-ChildItem node_modules\@ihason -Directory | ForEach-Object {
  $s = Get-ChildItem $_.FullName -Recurse -File | Measure-Object Length -Sum
  "{0}: {1} files, {2:N1} MB" -f $_.Name, $s.Count, ($s.Sum / 1MB)
}
```

正常结果：

```text
rust-portable: 2 files, 0.0 MB
rust-portable-win32-x64: 4 files, 0.0 MB
rust-portable-win32-x64-chunk-01: 3 files, 100.0 MB
...
rust-portable-win32-x64-chunk-06: 3 files, 82.7 MB
```

工具链不在 `node_modules` 中。
工具链位于：

```text
D:\my-project\rust-portable
```

使用自定义安装目录时，替换上述路径。

### 4.5 postinstall 未运行

使用 `--ignore-scripts` 时，分片包正常安装。
工具链不解压。

手动运行安装器：

```powershell
node node_modules\@ihason\rust-portable-win32-x64\install.js
```

pnpm 10 默认阻止依赖的构建脚本。
允许平台包执行脚本：

```powershell
pnpm approve-builds
```

### 4.6 重新安装

删除 npm 包：

```powershell
Remove-Item node_modules\@ihason -Recurse -Force
```

检查缓存：

```powershell
npm cache verify
```

重新安装：

```powershell
npm install @ihason/rust-portable --include=optional
```

彻底清理缓存：

```powershell
npm cache clean --force
```

### 4.7 npm 包中没有 configure-env.bat

`configure-env.bat` 不在 npm tarball 中。
`configure-env.bat` 在 Windows ZIP 负载中。
`install.js` 解压 ZIP 后，文件位于：

```text
<install dir>\windows\configure-env.bat
```

默认位置：

```text
D:\my-project\rust-portable\windows\configure-env.bat
```

`node_modules\@ihason\rust-portable-win32-x64` 中不会有该文件。
这是正常现象。

文件不存在时，按顺序检查：

1. 检查 `postinstall` 是否运行。见第 4.1 节。
2. 手动运行安装器：

   ```powershell
   node node_modules\@ihason\rust-portable-win32-x64\install.js
   ```

3. 检查安装目录：

   ```powershell
   Test-Path "D:\my-project\rust-portable\windows\configure-env.bat"
   ```

输出 `True` 后，运行配置脚本：

```powershell
& "D:\my-project\rust-portable\windows\configure-env.bat"
```

使用自定义安装目录时，替换上述路径。

## 5. 维护者构建与发布（可选）

npm 发布是可选的人工操作。
npm 发布不属于 Release 流程。
仓库当前不自动发布 npm 包。

### 5.1 文件位置

npm 脚本位于 `scripts/npm/`：

```text
scripts/npm/
├─ install.js    # 平台包的 postinstall 安装器
├─ build.mjs     # 生成 build/npm/ 下的 8 个包
└─ publish.mjs   # 发布分片包、平台包、入口包
```

### 5.2 准备

要求：

- Node.js 18 或更新版本。
- npm 9 或更新版本。
- npm 账号。
- 已构建 Windows ZIP 和 `dist/SHA256SUMS`。

构建 Windows ZIP：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

构建修订版：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision r2
```

确认文件存在：

```text
dist\rust-portable-v<version>[-r<N>]-windows-x64.zip
dist\SHA256SUMS
```

`build.mjs` 从 `dist/SHA256SUMS` 读取 ZIP 的 SHA256。
`build.mjs` 在切分后再次校验 SHA256。

### 5.3 构建 npm 包

设置 scope：

```powershell
$env:NPM_SCOPE = 'ihason'
```

构建：

```powershell
node scripts/npm/build.mjs
```

构建修订版：

```powershell
node scripts/npm/build.mjs r2
```

设置分片大小：

```powershell
$env:NPM_CHUNK_MB = '50'
node scripts/npm/build.mjs
```

`NPM_CHUNK_MB` 的范围是 1 至 200。
默认值是 100。

输出目录：

```text
build/
└─ npm/
   ├─ chunk-01/
   ├─ ...
   ├─ chunk-06/
   ├─ platform/
   └─ meta/
```

### 5.4 检查构建结果

检查平台包的 `archive.json`：

```powershell
Get-Content build\npm\platform\archive.json
```

确认以下内容：

- `zip` 是本次 ZIP 文件名。
- `size` 等于 ZIP 字节数。
- `sha256` 等于 `dist/SHA256SUMS` 中的值。
- `parts` 数量等于分片包数量。
- 所有分片的 `bytes` 之和等于 `size`。

检查包版本和依赖：

```powershell
Get-Content build\npm\meta\package.json
Get-Content build\npm\platform\package.json
```

### 5.5 试运行

```powershell
node scripts/npm/publish.mjs --dry-run
```

试运行调用 `npm publish --dry-run`。
试运行不修改 registry。

### 5.6 发布

登录 npm：

```powershell
npm login
```

发布：

```powershell
node scripts/npm/publish.mjs
```

脚本按以下顺序发布：

1. 分片包 `chunk-01` 至 `chunk-06`。
2. 平台包。
3. 入口包。

脚本跳过已发布的 `name@version`。
任一步失败时，脚本立即停止。
修复后重跑。

发布参数：

```text
--access public
--tag latest
--fetch-timeout=1800000
--fetch-retries=2
```

npm 要求 2FA 时，终端提示输入一次性密码。

人工发布不要设置 `NPM_PROVENANCE`。
`NPM_PROVENANCE` 只用于具备 `id-token` 的 CI。

### 5.7 验证发布

检查版本：

```powershell
npm view @ihason/rust-portable version
```

检查平台包依赖：

```powershell
npm view @ihason/rust-portable-win32-x64 dependencies --json
```

检查分片大小：

```powershell
npm view @ihason/rust-portable-win32-x64-chunk-01 dist.unpackedSize
```

分片的 `unpackedSize` 约为 104,858,760 字节。

在空目录做真实安装：

```powershell
mkdir C:\npm-install-test
cd C:\npm-install-test
npm init -y
npm install @ihason/rust-portable
```

确认以下内容：

- npm 输出 `added 8 packages`。
- `node_modules\@ihason` 下有 8 个目录。
- 前 5 个分片包各约 100 MB，第 6 个分片包约 82.7 MB。
- 工具链解压到 `C:\npm-install-test\rust-portable`。

### 5.8 发布修订版

npm 版本不可覆盖。
同一 Rust 版本重新发布时，使用修订号。

构建修订 ZIP：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision r2
```

构建修订 npm 包：

```powershell
$env:NPM_SCOPE = 'ihason'
node scripts/npm/build.mjs r2
```

发布：

```powershell
node scripts/npm/publish.mjs
```

修订包版本为 `1.99.1-r2`。
安装目录仍是执行目录下的 `rust-portable`。
安装器要求用 `RUST_PORTABLE_FORCE=1` 替换现有版本。

`publish.mjs` 中途失败时，修复后重跑。
脚本跳过已发布的分片包。
脚本继续发布未发布的分片包。

已发布版本有问题时，发布下一个修订号。
不要用 `npm unpublish` 删除已发布版本。
用户可能已经安装该版本。

### 5.9 清理

删除构建产物：

```powershell
Remove-Item build\npm -Recurse -Force
```

`build/npm` 约 611 MB。
npm 缓存也保留 tarball。

## 6. 限制

- npm 包只支持 Windows 10/11 x64。
- 安装器不访问网络。
- 默认安装目录是执行 `npm install` 的目录下的 `rust-portable`。
  项目路径不能含空格。
  可以在安装前设置 `RUST_PORTABLE_INSTALL_DIR` 到无空格的完整目录。
- 入口包使用 `optionalDependencies`。
  npm 静默忽略 optional 依赖的安装失败。
  排查方法见第 4.1 节。
- 升级会替换同一个安装目录。
  现有目录版本不同或不完整时，安装器要求 `RUST_PORTABLE_FORCE=1`。
- 分片包保留在 `node_modules` 中。
  分片约占 604 MB。
  删除 `node_modules` 不影响已安装的工具链。
- npm 网页不预览分片中的二进制文件。
  包是否完整，以 `dist.unpackedSize`、`fileCount` 和实际安装结果为准。
- 工具链组件使用各自的许可证。
  许可证位于解压目录的 `shared/licenses/` 和 `shared/THIRD-PARTY-NOTICES.md`。
