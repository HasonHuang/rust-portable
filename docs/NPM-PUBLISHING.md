# npm 发布逐步指南

## 1. 范围

本文指导维护者发布 npm 包。
本文只说明发布操作。
这里的“仓库”指 npm registry。

npm 发布是可选的人工操作。
npm 发布不属于 GitHub Release 流程。

安装、环境配置和故障排查见 `docs/NPM.md`。

## 2. 发布内容

一次发布包含以下包：

| 包 | 作用 |
| --- | --- |
| `@ihason/rust-portable` | 入口包 |
| `@ihason/rust-portable-win32-x64` | 平台包和安装器 |
| `@ihason/rust-portable-win32-x64-chunk-NN` | ZIP 数据分片 |

默认分片大小为 100 MiB。
默认生成 6 个分片，共 8 个包。
改变分片大小时，包数量变化。
实际数量见 `build/npm/platform/archive.json`。

工具链内容来自 Windows ZIP：

```text
dist\rust-portable-v<version>[-r<N>]-windows-x64.zip
```

npm 包的元数据和安装器来自：

- `scripts/npm/`
- `scripts/npm/build.mjs`

要发布指定内容，执行以下步骤：

1. 修改源文件。
2. 构建新的 Windows ZIP。
3. 生成新的 npm 包。
4. 发布新的 npm 版本。

必须遵守以下规则：

- 不要直接修改 `dist` 中的 ZIP。
- 不要直接修改 `build/npm` 中的包。
- 不要只发布一个分片包。
- 平台包和入口包固定依赖精确版本。
- 更新内容时，整套包一起发布新版本。

## 3. 一次性准备

要求：

- Windows 10/11 x64。
- Node.js 18 或更新版本，x64。
- npm 9 或更新版本。
- 7-Zip，或 Windows 自带的 `tar.exe`。
- 至少 5 GB 可用磁盘空间。
- npm 账号，并且有权发布到 `@ihason` scope。

检查环境：

```powershell
node -p "process.platform + ' ' + process.arch"
node --version
npm --version
```

预期输出：

```text
win32 x64
v20.x.x
10.x.x
```

登录 npm：

```powershell
npm login
npm whoami
```

`npm whoami` 必须输出你的 npm 用户名。

检查 registry：

```powershell
npm config get registry
```

预期输出：

```text
https://registry.npmjs.org/
```

使用自动化 token 时，执行：

```powershell
$env:NODE_AUTH_TOKEN = '<token>'
```

人工发布推荐使用 `npm login`。
不要把 token 写入仓库。

## 4. 选择版本

版本号位于仓库根目录的 `VERSION` 文件。
`VERSION` 等于 Rust 版本号。
格式为 `MAJOR.MINOR.PATCH`。

升级 Rust 版本时，先更新：

- `VERSION`
- `CHANGELOG.md`
- `shared/VERSIONS.md`（工具链版本变化时）

正常发布使用：

```text
<VERSION>
```

修订发布使用：

```text
<VERSION>-r<N>
```

示例：

```text
1.99.1
1.99.1-r2
1.99.1-r3
```

修订发布不修改 `VERSION`。
修订号只出现在 ZIP 文件名和 npm 包版本中。

必须遵守以下规则：

- npm 版本不可覆盖。
- 已发布的版本不能再发布。
- 同一版本需要更新内容时，增加修订号。
- 不要复用旧版本号。

检查现有版本：

```powershell
npm view @ihason/rust-portable version
npm view @ihason/rust-portable-win32-x64 versions --json
```

如果目标版本已经存在，选择下一个修订号，例如 `r3`。
如果包还不存在，`npm view` 报 404。
这表示还没有发布。继续操作。

## 5. 构建 Windows ZIP

前置条件：`windows/` 工具链完整。
如果缺少 `windows/cargo`、`windows/rustup` 或 `windows/toolchain`，先执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prepare-windows.ps1
```

### 5.1 正常发布

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1
```

输出：

```text
dist\rust-portable-v<version>-windows-x64.zip
dist\SHA256SUMS
```

### 5.2 修订发布

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision r2
```

输出：

```text
dist\rust-portable-v<version>-r2-windows-x64.zip
dist\SHA256SUMS
```

### 5.3 检查构建结果

```powershell
Get-ChildItem dist
Get-Content dist\SHA256SUMS
```

确认以下内容：

- ZIP 文件名包含正确的版本和修订号。
- `SHA256SUMS` 包含同一 ZIP 文件名。
- ZIP 文件大小大于 0。

`build-windows.ps1` 检查工具链版本和目录完整性。
正式发布不要使用 `-SkipDoctor`。

## 6. 生成 npm 包

### 6.1 设置 scope

```powershell
$env:NPM_SCOPE = 'ihason'
```

不要省略 `NPM_SCOPE`。
省略后生成无 scope 的包名，例如 `rust-portable`。
无 scope 包名与现有 `@ihason` 包不一致。

如果使用其他 scope，替换所有 `@ihason/` 包名和 `NPM_SCOPE` 值。

### 6.2 生成包

正常发布：

```powershell
node scripts/npm/build.mjs
```

修订发布：

```powershell
node scripts/npm/build.mjs r2
```

构建参数必须与 ZIP 一致：

| ZIP | 构建命令 |
| --- | --- |
| `rust-portable-v1.99.1-windows-x64.zip` | `node scripts/npm/build.mjs` |
| `rust-portable-v1.99.1-r2-windows-x64.zip` | `node scripts/npm/build.mjs r2` |

`build.mjs` 删除并重建 `build/npm`。
不要手工修改 `build/npm`。

可选分片大小：

```powershell
$env:NPM_CHUNK_MB = '50'
node scripts/npm/build.mjs
```

`NPM_CHUNK_MB` 的范围是 1 至 200。
默认值是 100。
一个版本发布后，不要改变该版本的分片大小。

### 6.3 检查输出目录

```powershell
Get-ChildItem build\npm
```

默认输出：

```text
chunk-01
chunk-02
chunk-03
chunk-04
chunk-05
chunk-06
platform
meta
```

### 6.4 检查包版本

```powershell
Get-Content build\npm\meta\package.json
Get-Content build\npm\platform\package.json
```

确认以下内容：

- `meta` 包名是 `@ihason/rust-portable`。
- `platform` 包名是 `@ihason/rust-portable-win32-x64`。
- 两个包的 `version` 都等于目标版本。
- `meta` 的 `optionalDependencies` 指向平台包。
- `platform` 的 `dependencies` 指向全部分片包。
- 所有依赖版本都等于目标版本。

### 6.5 检查 ZIP 元数据

```powershell
Get-Content build\npm\platform\archive.json
```

确认以下内容：

- `zip` 等于 `dist` 中的 ZIP 文件名。
- `size` 等于 ZIP 字节数。
- `sha256` 等于 `dist\SHA256SUMS` 中的值。
- `parts` 数量等于分片包数量。
- 所有分片的 `bytes` 之和等于 `size`。

`build.mjs` 在切分后重新计算 SHA256。
SHA256 不一致时，构建失败。
构建失败时，不要发布。

## 7. 试运行

执行：

```powershell
node scripts/npm/publish.mjs --dry-run
```

试运行执行 `npm publish --dry-run`。
试运行不修改 npm registry。

确认以下内容：

- 发布顺序是全部分片包、平台包、入口包。
- 每个包名和版本正确。
- 没有报错。

## 8. 发布

确认登录状态：

```powershell
npm whoami
```

执行发布：

```powershell
node scripts/npm/publish.mjs
```

脚本按以下顺序发布：

1. 全部分片包。
2. 平台包。
3. 入口包。

脚本行为：

- 已发布的 `name@version` 自动跳过。
- 任一步失败时立即停止。
- 修复后直接重跑。

发布顺序很重要。
入口包必须最后发布。
这样 registry 不出现入口包已存在、分片包缺失的状态。

npm 要求 2FA 时，终端提示输入一次性密码。

人工发布不要设置 `NPM_PROVENANCE`。
`NPM_PROVENANCE` 只用于具备 `id-token` 的 CI。

## 9. 验证发布

### 9.1 检查 registry

```powershell
npm view @ihason/rust-portable version
npm view @ihason/rust-portable-win32-x64 dependencies --json
npm view @ihason/rust-portable-win32-x64-chunk-01 dist.unpackedSize
```

确认以下内容：

- 入口包版本等于目标版本。
- 平台包依赖全部分片包。
- `chunk-01` 的 `unpackedSize` 约为 104,858,760 字节。

### 9.2 做干净安装

```powershell
mkdir D:\npm-install-test
cd D:\npm-install-test
npm init -y
npm install @ihason/rust-portable
```

确认以下内容：

- npm 输出 `added 8 packages`。
- `node_modules\@ihason` 下有 8 个目录。
- 分片包大小正确。
- 工具链解压到 `D:\npm-install-test\rust-portable`。
- `rust-portable\windows\configure-env.bat` 存在。

检查版本：

```powershell
Get-Content .\rust-portable\VERSION
```

清理测试目录：

```powershell
cd D:\
Remove-Item D:\npm-install-test -Recurse -Force
```

### 9.3 只安装了入口包

如果 `node_modules\@ihason` 下只有入口包，见 `docs/NPM.md` 第 4.1 节。

常见原因：

- `omit=optional`
- `--ignore-scripts`
- 安装路径含空格
- postinstall 失败

## 10. 发布修订版

npm 版本发布后不能修改。
需要更新内容时，执行以下步骤：

1. 修改 `windows/`、`shared/` 或构建脚本。
2. 选择新的修订号，例如 `r3`。
3. 构建修订 ZIP：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision r3
   ```

4. 生成 npm 包：

   ```powershell
   $env:NPM_SCOPE = 'ihason'
   node scripts/npm/build.mjs r3
   ```

5. 试运行：

   ```powershell
   node scripts/npm/publish.mjs --dry-run
   ```

6. 发布：

   ```powershell
   node scripts/npm/publish.mjs
   ```

7. 验证：

   ```powershell
   npm view @ihason/rust-portable version
   ```

发布中途失败时，执行以下步骤：

1. 修复网络或权限问题。
2. 重跑 `node scripts/npm/publish.mjs`。
3. 已成功的包自动跳过。
4. 未成功的包继续发布。

这是脚本的自动续发。
不要手工挑选单个包发布。

已发布版本有问题时，执行以下步骤：

1. 不要覆盖旧版本。
2. 不要使用 `npm unpublish`，除非确定没有用户安装。
3. 发布下一个修订号，例如 `r4`。
4. 在 Release Notes 中说明差异。

## 11. 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 包名没有 `@ihason/` | 没有设置 `NPM_SCOPE` | 设置 `$env:NPM_SCOPE = 'ihason'` 后重新构建 |
| `E403` | 没有 scope 权限，或版本已存在 | 检查 npm 账号权限 |
| `EPUBLISHCONFLICT` | 版本已存在 | 使用下一个修订号 |
| `Missing ...zip` | ZIP 未构建，或修订号不一致 | 先构建 ZIP，并统一命令参数 |
| `SHA256SUMS does not contain ...` | 校验和文件与 ZIP 不匹配 | 重新运行 `build-windows.ps1` |
| `SHA256 mismatch` | 构建过程中 ZIP 发生变化 | 重新构建 ZIP 和 npm 包 |
| 发布很慢或超时 | 分片包总量约 600 MB | 保持网络稳定，脚本已设置较长超时 |
| `EOTP` | npm 要求 2FA | 输入一次性密码，或配置 automation token |
| `dry-run` 通过，正式发布失败 | 登录、权限或 2FA 问题 | 检查 `npm whoami` 和 scope 权限 |
| 安装后只有入口包 | optional dependency 未安装 | 见 `docs/NPM.md` 第 4.1 节 |
| npm 网页看到分片为空 | 分片是二进制文件 | 查看 `dist.unpackedSize` |
| 安装后没有 `configure-env.bat` | postinstall 未运行 | 手动运行 `install.js`，见 `docs/NPM.md` 第 4.7 节 |

## 12. 检查清单

发布前：

- [ ] 代码已提交，工作区干净。
- [ ] 已确定目标版本或修订号。
- [ ] 目标版本在 registry 中不存在。
- [ ] 已构建 Windows ZIP。
- [ ] `dist\SHA256SUMS` 包含该 ZIP。
- [ ] 已设置 `NPM_SCOPE=ihason`。
- [ ] `build.mjs` 参数与 ZIP 修订号一致。
- [ ] `archive.json` 的 `size`、`sha256`、`parts` 正确。
- [ ] `npm whoami` 正常。
- [ ] `publish.mjs --dry-run` 通过。

发布后：

- [ ] `npm view @ihason/rust-portable version` 正确。
- [ ] 平台包依赖全部分片包。
- [ ] 空目录安装得到入口包、平台包和全部分片包。
- [ ] 工具链解压到 `rust-portable`。
- [ ] `rust-portable\windows\configure-env.bat` 存在。
- [ ] 测试目录已清理。

## 13. 快速命令

### 13.1 正常发布

```powershell
$env:NPM_SCOPE = 'ihason'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1
node scripts/npm/build.mjs
node scripts/npm/publish.mjs --dry-run
npm whoami
node scripts/npm/publish.mjs
```

### 13.2 修订发布

```powershell
$Revision = 'r2'
$env:NPM_SCOPE = 'ihason'
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Revision $Revision
node scripts/npm/build.mjs $Revision
node scripts/npm/publish.mjs --dry-run
npm whoami
node scripts/npm/publish.mjs
```

### 13.3 发布后验证

```powershell
npm view @ihason/rust-portable version
mkdir D:\npm-install-test
cd D:\npm-install-test
npm init -y
npm install @ihason/rust-portable
Test-Path .\rust-portable\windows\configure-env.bat
```
