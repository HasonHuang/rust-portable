# 发布说明（维护者）

本文说明如何构建和发布 `rust-portable`。

## 1. 版本号

版本号保存在仓库根目录的 `VERSION` 文件。
项目版本号与 Rust 版本号一致。
例如 Rust 1.99.1 对应项目版本 `1.99.1`。
格式为 `MAJOR.MINOR.PATCH`。

`VERSION` 是唯一工具链版本来源：

- `scripts/prepare-windows.ps1` 默认按它安装同一版本的 Rust。
- `scripts/build-windows.ps1` 会检查 `rustc --version` 必须等于它，否则构建失败。
- `scripts/prepare-linux.sh` 默认下载同一版本的 Rust 官方组件。
- `scripts/build-linux.sh` 会检查安装后的 `rustc --version` 必须等于它。
- 工作流读取它，正常发布标签为 `v<VERSION>`。

### 1.1 打包修订号

同一 Rust 版本需要重新打包时，不修改 `VERSION`。
使用修订标签和修订号：

```text
正常发布：v<VERSION>
打包修订：v<VERSION>-r<N>，例如 v1.99.1-r2
```

修订包的文件名包含修订号：

```text
rust-portable-v1.99.1-r2-windows-x64.zip
rust-portable-v1.99.1-r2-linux-x64.tar.gz
```

包内 `VERSION` 和 `BUILD-INFO.txt` 的 `Rust version` 仍是 `1.99.1`。
`BUILD-INFO.txt` 增加 `Bundle revision: r2`。

修订号只从标签或工作流输入读取，不写入 `VERSION`。
标签格式为 `v<MAJOR.MINOR.PATCH>` 或 `v<MAJOR.MINOR.PATCH>-r<N>`。

发布前同时更新：

- `VERSION`
- `CHANGELOG.md`
- `shared/VERSIONS.md`（工具链版本变化时）

Git 标签使用 `v` 前缀，例如 `v1.99.1`。

## 2. 本机构建发布包

### 2.1 Windows x64

前置条件：

- 当前工作目录已包含完整的 `windows/` 工具链。
- 已安装 7-Zip（脚本使用最高压缩级别 `-mx=9`），或系统自带 `tar.exe` 作为回退。
- PowerShell 5.1 或更高版本。

运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

输出：

```text
dist\rust-portable-v1.99.1-windows-x64.zip
dist\SHA256SUMS
```

打包修订版：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision r2
```

输出文件名：

```text
dist\rust-portable-v1.99.1-r2-windows-x64.zip
```

脚本会：

1. 从 `VERSION` 读取版本。
2. 把 `windows/`、`shared/`、README、LICENSE 复制到临时目录。
3. 写入 `VERSION` 和 `BUILD-INFO.txt`。
4. 校验打包的 `rustc --version` 等于发布版本。
5. 运行 `windows\doctor.bat --no-pause`。
6. 生成 ZIP 和 SHA256。

`-Version` 可以覆盖输出文件名中的版本，但工具链版本必须与之一致：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Version 1.99.1
```

保留临时目录以便检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -KeepStaging
```

跳过自检（只用于调试脚本）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -SkipDoctor
```

正式发布不要使用 `-SkipDoctor`。

#### 从零准备 Windows 工具链

如果工作目录中没有 `windows/cargo`、`windows/rustup` 或 `windows/toolchain`，先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-windows.ps1
```

脚本会下载固定版本的 `rustup-init.exe` 和 WinLibs MinGW-w64。
两者都用 `shared/VERSIONS.md` 中的 SHA256 校验。
然后安装 `VERSION` 指定的 Rust 版本和常用组件。

也可以显式指定 Rust 版本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-windows.ps1 -RustVersion 1.99.1
```

GitHub Actions 使用同一个脚本准备工具链。

### 2.2 Linux x64

前置条件：

- 完整自检需要 Linux x64 和 gcc、g++、make。
- macOS 可以用 `--skip-doctor` 只组装安装包。
- Python 3.11 或更新（`tomllib`）。
- curl、tar、xz。

下载并校验 Rust 官方组件：

```bash
bash scripts/prepare-linux.sh --version 1.99.1
```

脚本执行以下动作：

1. 下载 `channel-rust-1.99.1.toml` 和 `.sha256`。
2. 校验清单 SHA256。
3. 从清单读取 7 个组件的 `xz_url` 和 `xz_hash`。
4. 下载组件到 `build/linux-packages/1.99.1/`。
5. 校验每个组件，生成 `SHA256SUMS`。

使用内网 Rust 镜像：

```bash
bash scripts/prepare-linux.sh \
  --version 1.99.1 \
  --dist-server https://mirror.example.com/rustup
```

然后构建安装包：

```bash
bash scripts/build-linux.sh --version 1.99.1
```

输出：

```text
dist/rust-portable-v1.99.1-linux-x64.tar.gz
dist/SHA256SUMS.linux
```

打包修订版：

```bash
bash scripts/build-linux.sh --version 1.99.1 --revision r2
```

输出文件名：

```text
dist/rust-portable-v1.99.1-r2-linux-x64.tar.gz
```

脚本执行以下动作：

1. 从 `VERSION` 读取版本。
2. 缺少组件时调用 `prepare-linux.sh`。
3. 把 `linux/`、`shared/`、README、LICENSE 和组件包复制到临时目录。
4. 写入 `VERSION` 和 `BUILD-INFO.txt`。
5. 在临时前缀中离线安装，运行 `doctor.sh` 和示例程序。
6. 生成 tar.gz 和 SHA256。

跳过自检（只用于调试脚本）：

```bash
bash scripts/build-linux.sh --version 1.99.1 --skip-doctor
```

保留临时目录：

```bash
bash scripts/build-linux.sh --version 1.99.1 --keep-staging
```

离线容器测试：

```bash
bash scripts/test-linux-docker.sh \
  --bundle dist/rust-portable-v1.99.1-linux-x64.tar.gz
```

测试使用 `oraclelinux:8`。
容器先联网安装 gcc、g++、make、tar、xz。
然后容器在 `--network none` 下安装、自检、补装组件和卸载。

Linux 包不使用 rustup。
组件清单：

- rustc
- cargo
- rust-std
- rustfmt
- clippy
- rust-analyzer
- rust-src

新增组件时：

1. 在 `scripts/prepare-linux.sh` 的 `COMPONENT_NAMES` 增加清单包名。
2. 重新运行 `prepare-linux.sh` 和 `build-linux.sh`。
3. `install.sh` 会自动安装 `linux/packages/*.tar.xz`，不需要改安装逻辑。
4. 已安装的机器重跑新的 `install.sh`，或用 `add-component.sh` 补装。
5. 更新 `linux/README.md` 和 `shared/VERSIONS.md`。

同一 Rust 版本只增加组件时，按第 5.1 节更新现有 Release。

## 3. 发布前验证

### 3.1 Windows

1. 在一个新目录解压 ZIP。
2. 确认顶层目录是 `rust-portable/`。
3. 确认目录中没有 `dist/`、`.git/`、`target/`、Cargo 缓存。
4. 双击 `windows\configure-env.bat`。
5. 重新打开终端。
6. 运行 `windows\doctor.bat`。
7. 运行示例：

```bat
cargo run --manifest-path shared\examples\hello\Cargo.toml
```

8. 校验 SHA256：

```bat
certutil -hashfile rust-portable-v1.99.1-windows-x64.zip SHA256
```

输出必须与 `SHA256SUMS` 一致。

### 3.2 Linux

1. 在一个新目录解压 tar.gz。
2. 确认顶层目录是 `rust-portable/`。
3. 确认目录中有 `linux/packages/SHA256SUMS`。
4. 运行离线容器测试：

```bash
bash scripts/test-linux-docker.sh \
  --bundle dist/rust-portable-v1.99.1-linux-x64.tar.gz
```

容器测试执行安装、自检、示例、补装组件和卸载。
5. 在干净的 RHEL 8/9 或 Oracle Linux 8/9 机器断网安装一次。
6. 运行 `doctor.sh` 和示例。
7. 校验 SHA256：

```bash
sha256sum -c SHA256SUMS --ignore-missing
```

输出必须与 `SHA256SUMS` 中的 Linux 行一致。

修订版把示例中的 `v1.99.1` 替换为 `v1.99.1-r2`。

## 4. 提交并打标签

推荐提交后直接在 Actions 中运行 `Release` 工作流（见第 7 节），由工作流创建标签和 Release。

如果手动操作，标签必须与 `VERSION` 一致，否则工作流会拒绝构建：

```bash
git status
git add .
git commit -m "Release v1.99.1"
git tag -a v1.99.1 -m "rust-portable v1.99.1"
git push origin main
git push origin v1.99.1
```

确认 `git status` 中没有工具链目录。
`git count-objects -vH` 显示的仓库体积应只有几 MB。

## 5. 手动创建 GitHub Release（备用）

工作流不可用时，才需要本地构建并手动发布。
需要 GitHub CLI：

```bash
gh auth login
```

合并校验和：

```bash
cat dist/SHA256SUMS dist/SHA256SUMS.linux > dist/SHA256SUMS.merged
mv dist/SHA256SUMS.merged dist/SHA256SUMS
```

创建草稿：

```bash
gh release create v1.99.1 \
  dist/rust-portable-v1.99.1-windows-x64.zip \
  dist/rust-portable-v1.99.1-linux-x64.tar.gz \
  dist/SHA256SUMS \
  --title "rust-portable v1.99.1" \
  --notes-file docs/release-notes/v1.99.1.md \
  --draft
```

检查资产后发布：

```bash
gh release edit v1.99.1 --draft=false
```

### 5.1 同一 Rust 版本重新打包

推荐创建修订 Release。
不修改 `VERSION`，使用 `v<VERSION>-r<N>` 标签：

```bash
gh release create v1.99.1-r2 \
  dist/rust-portable-v1.99.1-r2-windows-x64.zip \
  dist/rust-portable-v1.99.1-r2-linux-x64.tar.gz \
  dist/SHA256SUMS \
  --title "rust-portable v1.99.1-r2" \
  --notes-file docs/release-notes/v1.99.1-r2.md \
  --draft
```

原 Release 保持不变。

只有在必须修复已发布 Release 的资产时，才替换现有资产：

```bash
gh release download v1.99.1 -p SHA256SUMS -O dist/SHA256SUMS.existing
cat dist/SHA256SUMS.existing dist/SHA256SUMS.linux > dist/SHA256SUMS
gh release upload v1.99.1 \
  dist/rust-portable-v1.99.1-linux-x64.tar.gz \
  dist/SHA256SUMS --clobber
```

替换后更新 Release Notes。

## 6. Release Notes 模板

```markdown
## rust-portable v1.99.1

### 平台

- Windows 10/11 x64
- Linux x64（RHEL 系，glibc 2.17+）

### 工具链

- Rust 1.99.1
- Cargo 1.99.1
- rustup 1.29.2（仅 Windows）
- MinGW-w64 GCC 16.2.0（仅 Windows）
- Windows target: x86_64-pc-windows-gnu
- Linux target: x86_64-unknown-linux-gnu
- Linux 组件：rustc、cargo、rust-std、rustfmt、clippy、rust-analyzer、rust-src

### 资产

- rust-portable-v1.99.1-windows-x64.zip
- rust-portable-v1.99.1-linux-x64.tar.gz
- SHA256SUMS

修订版把文件名中的 `v1.99.1` 替换为 `v1.99.1-r2`。

### 安装（Windows）

1. 解压到不含空格的路径。
2. 运行 `windows\configure-env.bat`。
3. 重新打开终端。
4. 运行 `windows\doctor.bat`。

### 安装（Linux）

1. 解压到不含空格的路径。
2. 安装依赖：`sudo dnf install -y gcc gcc-c++ make`。
3. 系统级安装：`sudo linux/install.sh`。
4. 打开新终端。
5. 运行 `/opt/rust-portable/share/rust-portable/doctor.sh`。

### 已知限制

- Windows 路径不能包含空格。
- Linux 安装前缀不能包含空格。
- 仅支持 x64。
- Linux 包不包含 GCC；GCC 由系统仓库提供。
- Linux 包默认不包含 rust-docs 和 llvm-tools。
- 第三方 crate 仍需要内网镜像或 vendor 目录。
```

## 7. 自动化发布

仓库包含 `.github/workflows/release.yml`。
发布版本号取自 `VERSION`，也就是 Rust 版本号。
正常标签为 `v<VERSION>`。
打包修订标签为 `v<VERSION>-r<N>`。

工作流支持两种触发方式：

**推送标签**

```bash
git tag -a v1.99.1 -m "rust-portable v1.99.1"
git push origin v1.99.1
```

同一 Rust 版本重新打包：

```bash
git tag -a v1.99.1-r2 -m "rust-portable v1.99.1-r2"
git push origin v1.99.1-r2
```

标签必须是 `v<VERSION>` 或 `v<VERSION>-r<N>`，否则工作流在第一步失败。

**手动运行**

Actions → `Release` → `Run workflow`。
版本仍然从 `VERSION` 读取。
可选 `revision` 输入，例如 `r2`；留空表示正常发布。
可选 `draft` 输入，先建草稿 Release 而不直接公开。
可选 `dry_run` 输入，只构建并上传 Actions artifact，不创建标签或 Release。
如果该标签的 Release 已公开发布，工作流会拒绝重复构建。
同一 Rust 版本重新打包时，使用新的修订号。

首次切换或验证工作流时，先运行一次 dry run：

```bash
gh workflow run Release --ref main -f dry_run=true
```

修订版 dry run：

```bash
gh workflow run Release --ref main -f revision=r2 -f dry_run=true
```

dry run 会完整执行两个平台的工具链准备、打包、自检和 Linux 离线容器测试，但不会改动标签和 Release。
例如 `v1.99.1` 已手动发布时，dry run 不会产生版本冲突。
产物在对应 run 的 Artifacts 中下载，保留 7 天。

工作流执行：

1. `resolve`：读取 `VERSION`，解析标签或 `revision` 输入，生成 `tag` 和 `asset_version`；dry run 时跳过 Release 检查。
2. `build-windows`：在 `windows-latest` 上运行 `prepare-windows.ps1 -RustVersion <VERSION>`，安装同一版本的 Rust。
3. 运行 `build-windows.ps1 -Version <VERSION> -Revision <REVISION>`，校验 `rustc --version` 等于 Rust 版本，然后打包、自检、生成 SHA256。
4. `build-linux`：在 `ubuntu-latest` 上运行 `prepare-linux.sh` 和 `build-linux.sh --revision <REVISION>`。
5. 运行 `test-linux-docker.sh`，在 `oraclelinux:8` 容器中做离线测试。
6. `publish`：分别下载两个 artifact，合并 `SHA256SUMS`，创建或复用 Release，上传 ZIP、tar.gz 和校验和，最后发布；dry run 时跳过。

正常发布的资产名：

```text
rust-portable-v1.99.1-windows-x64.zip
rust-portable-v1.99.1-linux-x64.tar.gz
```

修订发布的资产名：

```text
rust-portable-v1.99.1-r2-windows-x64.zip
rust-portable-v1.99.1-r2-linux-x64.tar.gz
```

工作流启用前，必须先确认：

- 仓库 Settings → Actions → General → Workflow permissions 允许读写。
- 固定版本的下载地址和 SHA256 不变。
- Windows 自检通过。
- Linux 离线容器测试通过。
- 大文件资产没有超过 GitHub 单文件 2 GiB 限制。

## 8. 平台资产命名

```text
rust-portable-v<version>[-r<N>]-windows-x64.zip
rust-portable-v<version>[-r<N>]-linux-x64.tar.gz
```

全部资产上传到同一个 Release。
每个 Release 附带一个 `SHA256SUMS`。
修订版使用独立 Release 标签 `v<version>-r<N>`。
`SHA256SUMS` 包含 Windows 和 Linux 两行。

本地构建时：

- Windows 脚本写 `dist/SHA256SUMS`。
- Linux 脚本写 `dist/SHA256SUMS.linux`。
- 手动发布前合并：

```bash
cat dist/SHA256SUMS dist/SHA256SUMS.linux > dist/SHA256SUMS.merged
mv dist/SHA256SUMS.merged dist/SHA256SUMS
```

GitHub Actions 的 `publish` 会自动完成合并。

## 9. npm 发布（可选）

npm 发布是可选的人工操作。
npm 发布不属于 Release 流程。
完整步骤见 `docs/NPM.md`。

脚本位置：

- `scripts/npm/build.mjs`：从 `dist` 中的 Windows ZIP 生成 8 个 npm 包。
- `scripts/npm/publish.mjs`：按分片包、平台包、入口包的顺序发布。

正常发布时，npm 包版本等于 `VERSION`。
修订发布时，npm 包版本为 `<VERSION>-r<N>`，例如 `1.99.1-r2`。
同一 Rust 版本重新发布时使用修订号。
npm 版本不可覆盖。已发布版本有问题时，发布新的修订号。
