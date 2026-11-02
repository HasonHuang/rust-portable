# 发布说明（维护者）

本文说明如何构建和发布 `rust-portable`。

## 1. 版本号

版本号保存在仓库根目录的 `VERSION` 文件。
项目版本号与 Rust 版本号一致。
例如 Rust 1.99.1 对应项目版本 `1.99.1`。
格式为 `MAJOR.MINOR.PATCH`。

发布前同时更新：

- `VERSION`
- `CHANGELOG.md`
- `shared/VERSIONS.md`（工具链版本变化时）

Git 标签使用 `v` 前缀，例如 `v1.99.1`。

## 2. 本机构建 Windows 包

前置条件：

- 当前工作目录已包含完整的 `windows/` 工具链。
- 已安装 7-Zip，或系统自带 `tar.exe`。
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

脚本会：

1. 从 `VERSION` 读取版本。
2. 把 `windows/`、`shared/`、README、LICENSE 复制到临时目录。
3. 写入 `BUILD-INFO.txt`。
4. 运行 `windows\doctor.bat --no-pause`。
5. 生成 ZIP 和 SHA256。

保留临时目录以便检查：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -KeepStaging
```

跳过自检（只用于调试脚本）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -SkipDoctor
```

正式发布不要使用 `-SkipDoctor`。

### 从零准备 Windows 工具链

如果工作目录中没有 `windows/cargo`、`windows/rustup` 或 `windows/toolchain`，先运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-windows.ps1
```

脚本会下载固定版本的 `rustup-init.exe` 和 WinLibs MinGW-w64。
两者都用 `shared/VERSIONS.md` 中的 SHA256 校验。
然后安装 Rust 1.99.1 和常用组件。

GitHub Actions 使用同一个脚本准备工具链。

## 3. 发布前验证

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

## 4. 提交并打标签

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

## 5. 创建 GitHub Release

需要 GitHub CLI：

```bash
gh auth login
```

创建草稿：

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

## 6. Release Notes 模板

```markdown
## rust-portable v1.99.1

### 平台

- Windows 10/11 x64

### 工具链

- Rust 1.99.1
- Cargo 1.99.1
- rustup 1.29.2
- MinGW-w64 GCC 16.2.0
- Target: x86_64-pc-windows-gnu

### 资产

- rust-portable-v1.99.1-windows-x64.zip
- SHA256SUMS

### 安装

1. 解压到不含空格的路径。
2. 运行 `windows\configure-env.bat`。
3. 重新打开终端。
4. 运行 `windows\doctor.bat`。

### 已知限制

- Windows 路径不能包含空格。
- 仅支持 Windows 10/11 x64。
- Linux 支持尚未包含。
```

## 7. 自动化发布

仓库包含 `.github/workflows/release.yml`。
推送 `v*` 标签时，工作流会：

1. 校验标签和 `VERSION`。
2. 创建草稿 Release。
3. 在 `windows-latest` 上准备工具链。
4. 构建 Windows 压缩包并上传。
5. 发布 Release。

工作流启用前，必须先确认：

- 仓库 Settings → Actions → General → Workflow permissions 允许读写。
- 固定版本的下载地址和 SHA256 不变。
- Windows 自检通过。
- 大文件资产没有超过 GitHub 单文件 2 GiB 限制。

## 8. 平台资产命名

```text
rust-portable-v<version>-windows-x64.zip
rust-portable-v<version>-linux-x64.tar.gz
```

全部资产上传到同一个 Release。
每个 Release 附带一个 `SHA256SUMS`。
