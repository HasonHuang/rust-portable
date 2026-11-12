# 发布文件到 npm registry

## 目录

**通用**

- 1. 范围

**自动准备**

- 2. 自动准备脚本（推荐）

**手动发布**

- 3. 手动发布步骤概览
- 4. 先选择方案
- 5. 准备环境
- 6. 定义名称和版本
- 7. 检查源文件
- 8. 切分文件
- 9. 创建分片包
- 10. 创建加载器包
- 11. 创建入口包
- 12. 发布前检查
- 13. 试运行发布
- 14. 正式发布
- 15. 验证发布
- 16. 常见问题
- 17. 更新内容
- 18. 检查清单
- 19. 快速命令

## 1. 范围

示例文件是 `a.zip`。
`a.zip` 不存在。
不要直接执行示例命令。
操作时替换文件、scope 和版本。

## 2. 自动准备脚本（推荐）

仓库提供通用脚本：

```text
docs/npm/prepare-publish.mjs
```

脚本只准备包和发布命令。
脚本不发布。

### 2.1 文件输入

在仓库根目录执行：

```bash
node docs/npm/prepare-publish.mjs a.zip \
  --scope '@your-scope' \
  --name a \
  --version 1.0.0
```

不设置 `--name` 或 `--package-name` 时，包名使用输入文件名去掉扩展名。

自定义完整包名：

```bash
node docs/npm/prepare-publish.mjs a.zip \
  --package-name '@your-scope/custom' \
  --version 1.0.0
```

`a.zip` 不存在。
示例会失败。
使用真实文件。

### 2.2 文件夹输入

```bash
node docs/npm/prepare-publish.mjs ./a \
  --scope '@your-scope' \
  --name a \
  --version 1.0.0
```

脚本先把文件夹压缩为 `build/npm-publish/a.zip`。

### 2.3 脚本行为

1. 检查输入。
2. 文件夹输入先压缩。
3. 计算大小和 SHA256。
4. 大于阈值时切分。阈值默认等于分片大小。
5. 生成 `package`，或生成 `chunk-NN`、`loader`、`meta`。
6. 分片模式生成 `install.js` 和 `archive.json`。
7. 生成 `publish.sh`。
8. 打印发布命令。

默认输出：

```text
build/npm-publish/
├─ chunk-01/
├─ ...
├─ loader/
├─ meta/
└─ publish.sh
```

单包模式输出：

```text
build/npm-publish/
├─ package/
│  ├─ package.json
│  ├─ README.md
│  └─ a.zip
└─ publish.sh
```

文件夹输入还会在输出目录生成 `<name>.zip`。

### 2.4 选项

| 选项 | 默认值 | 说明 |
| --- | --- | --- |
| `--scope` | `NPM_SCOPE` 或 `your-scope` | npm scope |
| `--name` | 输入文件名（去掉扩展名） | 包基础名 |
| `--package-name` | 无 | 包基础名或 `@scope/name`；覆盖 `--name` |
| `--version` | `1.0.0` | 包版本 |
| `--platform` | `win32-x64` | `os-cpu`；`any` 表示不写 |
| `--chunk-size` | `100` | 分片大小，MiB |
| `--threshold` | `--chunk-size`（100） | 超过此大小时分片，MiB |
| `--out` | `build/npm-publish` | 输出目录 |
| `--strip-components` | 文件夹 `1`，文件 `0` | 解压时去掉的顶层目录数 |
| `--force` | 关闭 | 替换输出目录 |
| `--help` | - | 显示帮助 |

### 2.5 执行发布

脚本打印命令，例如：

```text
npm login
npm whoami
npm publish '.../chunk-01' --access public --tag latest
...
```

脚本同时写入：

```text
build/npm-publish/publish.sh
```

用户检查命令后执行。

### 2.6 注意

- 脚本不执行 `npm publish`。
- 脚本不登录 npm。
- 单包模式只发布文件，不解压。
- 需要自动解压时，设置 `--threshold 0`。
- 脚本拒绝 `0.0.0-*` 占位版本。
- 默认版本是 `1.0.0`。
- 默认安装目录是 `<执行 npm install 的目录>/<name>`。
- 可用 `NPM_PAYLOAD_INSTALL_DIR` 指定完整安装目录。
- Windows 安装使用 `tar.exe`。
- 非 Windows 系统安装时需要 `unzip`。
- 非 Windows 平台发布时，设置 `--platform any` 或对应 `os-cpu`。
- 输出目录非空时脚本失败。使用 `--force` 替换。
- 发布前必须检查 `archive.json` 和 `publish.sh`。

## 3. 手动发布步骤概览

1. 准备环境。
2. 登录 npm。
3. 选择版本，确认 registry 中没有该版本。
4. 检查输入文件，记录大小和 SHA256。
5. 大于 100 MiB 时切分文件。
6. 大文件创建分片包、加载器包和入口包。
7. 检查包和 `archive.json`。
8. 试运行发布。
9. 大文件按分片包、加载器包、入口包的顺序发布。
   小文件直接发布单包。
10. 在空目录安装验证。

## 4. 先选择方案

npm 发布的是 npm 包，不是单独的文件。
文件必须放在包目录中。

### 4.1 小文件

默认情况下，文件不大于 100 MiB 时，发布一个包。
示例：

```text
build/a/
├─ package.json
└─ a.zip
```

`package.json` 示例：

```json
{
  "name": "@your-scope/a",
  "version": "1.0.0",
  "files": ["a.zip"],
  "publishConfig": {
    "access": "public"
  }
}
```

发布：

```bash
npm publish build/a --access public
```

### 4.2 大文件

文件较大时，单个 npm tarball 可能超过上传限制。
这时使用分片方案。

使用 3 层结构：

| 层 | 作用 |
| --- | --- |
| 入口包 | 用户安装的包 |
| 加载器包 | 依赖分片包，拼接并解压 |
| 分片包 | 保存 ZIP 的二进制分片 |

安装流程：

1. npm 安装入口包。
2. 入口包安装加载器包。
3. 加载器包安装全部分片包。
4. 加载器包运行 `postinstall`。
5. `postinstall` 拼接分片。
6. `postinstall` 校验 SHA256。
7. `postinstall` 解压到安装目录。

## 5. 准备环境

要求：

- Node.js 18 或更新版本。
- npm 9 或更新版本。
- npm 账号。
- 有权限发布到目标 scope。
- 至少 5 GB 可用磁盘空间。

检查环境：

```bash
node -p "process.platform + ' ' + process.arch"
node --version
npm --version
```

登录 npm：

```bash
npm login
npm whoami
```

`npm whoami` 必须输出你的 npm 用户名。

检查 registry：

```bash
npm config get registry
```

预期输出：

```text
https://registry.npmjs.org/
```

使用自动化 token 时：

```bash
export NODE_AUTH_TOKEN='<token>'
```

不要把 token 写入仓库。

## 6. 定义名称和版本

示例参数：

| 项目 | 示例值 |
| --- | --- |
| 文件 | `a.zip` |
| scope | `@your-scope` |
| 版本 | `1.0.0` |
| 分片大小 | 100 MiB |
| 安装目录 | `a` |

包名示例：

```text
@your-scope/a
@your-scope/a-win32-x64
@your-scope/a-win32-x64-chunk-01
@your-scope/a-win32-x64-chunk-02
```

规则：

- 所有包使用同一版本。
- 加载器包固定依赖分片包的精确版本。
- 入口包固定依赖加载器包的精确版本。
- npm 版本不可覆盖。
- 已发布的版本不能再发布。
- 同一版本需要更新内容时，使用新版本或修订号。

检查版本是否存在：

```bash
npm view @your-scope/a version
npm view @your-scope/a-win32-x64 versions --json
```

如果包还不存在，`npm view` 报 404。
这表示还没有发布。继续操作。

如果目标版本已存在，选择新版本。
例如：

```text
1.0.1
1.0.0-r2
1.0.0-r3
```

## 7. 检查源文件

计算文件大小和 SHA256：

```bash
wc -c < a.zip
sha256sum a.zip
```

记录以下值：

- 文件大小，单位为字节。
- SHA256，统一使用小写。

示例输出：

```text
123456789
abcdef...  a.zip
```

`a.zip` 不存在时，命令报错。
这是预期结果。
操作时使用真实文件。

macOS 使用 `shasum -a 256 a.zip`。

## 8. 切分文件

每个分片不超过 100 MiB。
100 MiB 等于 104,857,600 字节。

切分脚本自动创建输出目录。

切分命令示例：

```bash
mkdir -p build
split -b 100M -d -a 2 --numeric-suffixes=1 a.zip build/part

i=0
for file in build/part*; do
  i=$((i + 1))
  number=$(printf '%02d' "$i")
  mkdir -p "build/chunk-$number"
  mv "$file" "build/chunk-$number/part$number"
done
```

示例使用 GNU coreutils 的 `split`。
分片超过 99 个时，把 `-a 2` 改为 `-a 3`，并同步包名。

输出示例：

```text
build/chunk-01/part01
build/chunk-02/part02
...
```

检查分片：

```bash
ls -l build/chunk-*/*
```

确认：

- 每个分片不超过 104,857,600 字节。
- 最后一个分片更小。
- 所有分片大小之和等于 `a.zip` 大小。

## 9. 创建分片包

每个分片目录需要一个 `package.json`。

`build/chunk-01/package.json` 示例：

```json
{
  "name": "@your-scope/a-win32-x64-chunk-01",
  "version": "1.0.0",
  "description": "a.zip data chunk 01",
  "os": ["win32"],
  "cpu": ["x64"],
  "files": ["part01"],
  "publishConfig": {
    "access": "public"
  }
}
```

要求：

- `name` 必须唯一。
- `version` 必须等于目标版本。
- `files` 必须包含分片文件。
- 分片文件放在同一目录。
- 分片文件不需要扩展名。

示例使用 Windows x64。
发布其他平台时，修改 `os` 和 `cpu`。

对其他分片重复以上步骤。
每个分片使用独立包名和独立目录。

## 10. 创建加载器包

加载器包负责拼接、校验和解压。

目录示例：

```text
build/loader/
├─ package.json
├─ archive.json
└─ install.js
```

`package.json` 示例：

```json
{
  "name": "@your-scope/a-win32-x64",
  "version": "1.0.0",
  "description": "a.zip loader for Windows x64",
  "os": ["win32"],
  "cpu": ["x64"],
  "files": ["install.js", "archive.json"],
  "scripts": {
    "postinstall": "node install.js"
  },
  "dependencies": {
    "@your-scope/a-win32-x64-chunk-01": "1.0.0",
    "@your-scope/a-win32-x64-chunk-02": "1.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

要求：

- `dependencies` 列出全部分片包。
- 版本必须精确匹配。
- 不要使用 `^` 或 `~`。
- `postinstall` 必须运行安装器。

示例只列出 2 个分片。
实际列出全部分片包。

`archive.json` 示例：

```json
{
  "zip": "a.zip",
  "size": 123456789,
  "sha256": "abcdef...",
  "parts": [
    {
      "package": "@your-scope/a-win32-x64-chunk-01",
      "file": "part01",
      "bytes": 104857600
    },
    {
      "package": "@your-scope/a-win32-x64-chunk-02",
      "file": "part02",
      "bytes": 18599189
    }
  ]
}
```

要求：

- `size` 等于 ZIP 字节数。
- `sha256` 等于 ZIP 的 SHA256。
- `parts` 按顺序列出全部分片。
- 所有 `bytes` 之和等于 `size`。
- SHA256 统一使用小写。

示例只列出 2 个分片。
实际列出全部分片。

`install.js` 必须执行以下步骤：

1. 读取 `archive.json`。
2. 用 `require.resolve` 找到每个分片包。
3. 按顺序把分片追加到临时 ZIP。
4. 计算总字节数。
5. 计算 SHA256。
6. 校验字节数和 SHA256。
7. 解压到安装目录。
8. 写入完成标记。

安装目录建议：

```text
<执行 npm install 的目录>/a
```

`postinstall` 的当前目录是包目录，不是项目目录。
使用 `INIT_CWD` 获取执行 `npm install` 的目录。
安装路径不能含空格。
如果 ZIP 有顶层目录，解压时去掉顶层目录，避免多一层。

完整参考实现见本仓库的 `scripts/npm/install.js`。

## 11. 创建入口包

入口包是用户安装的包。

目录示例：

```text
build/meta/
├─ package.json
└─ README.md
```

`package.json` 示例：

```json
{
  "name": "@your-scope/a",
  "version": "1.0.0",
  "description": "a.zip portable package",
  "files": ["README.md"],
  "optionalDependencies": {
    "@your-scope/a-win32-x64": "1.0.0"
  },
  "publishConfig": {
    "access": "public"
  }
}
```

要求：

- 使用 `optionalDependencies` 依赖加载器包。
- 其他平台安装时，npm 跳过加载器包。
- 入口包不包含二进制内容。
- 版本必须与加载器包一致。

注意：optional dependency 失败时，npm 可能静默跳过。
安装后必须验证。

## 12. 发布前检查

检查包名和版本：

```bash
cat build/meta/package.json
cat build/loader/package.json
cat build/loader/archive.json
```

确认：

- 所有包名正确。
- 所有版本一致。
- 所有依赖版本精确。
- `archive.json` 的 `size`、`sha256`、`parts` 正确。
- 分片包数量等于 `parts` 数量。

检查包内容：

```bash
npm pack build/chunk-01 --dry-run
npm pack build/loader --dry-run
npm pack build/meta --dry-run
```

`npm pack --dry-run` 不发布包。
它显示包内文件列表。

## 13. 试运行发布

```bash
npm publish build/chunk-01 --access public --dry-run
npm publish build/loader --access public --dry-run
npm publish build/meta --access public --dry-run
```

确认：

- 包名正确。
- 版本正确。
- 文件列表正确。
- 没有报错。

试运行不修改 registry。

## 14. 正式发布

确认登录：

```bash
npm whoami
```

发布顺序必须是：

1. 全部分片包。
2. 加载器包。
3. 入口包。

分片包示例：

```bash
for dir in build/chunk-*; do
  npm publish "$dir" --access public --tag latest || exit 1
done
```

发布加载器包：

```bash
npm publish build/loader --access public --tag latest
```

发布入口包：

```bash
npm publish build/meta --access public --tag latest
```

规则：

- 入口包必须最后发布。
- 不要先发布入口包。
- 不要只发布一个分片包。
- npm 要求 2FA 时，终端提示输入一次性密码。
- 已发布的版本不能覆盖。

发布中途失败时：

1. 修复网络或权限问题。
2. 检查已发布的包。
3. 跳过已发布的版本。
4. 继续发布剩余包。

## 15. 验证发布

检查 registry：

```bash
npm view @your-scope/a version
npm view @your-scope/a-win32-x64 dependencies --json
npm view @your-scope/a-win32-x64-chunk-01 dist.unpackedSize
```

确认：

- 入口包版本正确。
- 加载器包依赖全部分片包。
- 分片包大小正确。

做一次干净安装：

```bash
mkdir -p a-test
cd a-test
npm init -y
npm install @your-scope/a
```

确认：

- npm 安装入口包、加载器包和全部分片包。
- `node_modules` 中有对应目录。
- 安装目录中存在解压后的 `a.zip` 内容。
- 安装器输出 SHA256 校验成功。

检查安装目录：

```bash
ls -la a
```

清理测试目录：

```bash
cd ..
rm -rf a-test
```

如果只安装了入口包，见第 16 节。

## 16. 常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 包名没有 scope | 发布时没有使用 scope | 在 `package.json` 中写完整包名 |
| `E403` | 没有 scope 权限 | 检查 npm 账号和 scope 权限 |
| `EPUBLISHCONFLICT` | 版本已存在 | 使用新版本 |
| `Missing data chunk` | 分片包未安装 | 检查 `dependencies` 和安装日志 |
| `Archive verification failed` | 分片顺序或 SHA256 错误 | 检查 `archive.json` 和分片文件 |
| 只安装了入口包 | optional dependency 未安装 | 使用 `npm install --include=optional` |
| 安装后没有解压 | `postinstall` 未运行 | 手动运行 `node node_modules/@your-scope/a-win32-x64/install.js` |
| npm 网页看不到分片内容 | 分片是二进制文件 | 检查 `dist.unpackedSize` |
| 安装路径错误 | 使用了包目录或含空格路径 | 使用 `INIT_CWD`，并使用无空格路径 |
| 发布很慢或超时 | 包体积较大 | 保持网络稳定，分批重试 |

### 16.1 只安装了入口包

检查：

```bash
npm config get omit
npm ls @your-scope/a --all
```

重新安装：

```bash
npm install @your-scope/a --include=optional
```

如果仍然失败，手动运行安装器：

```bash
npm install @your-scope/a --include=optional --ignore-scripts
node node_modules/@your-scope/a-win32-x64/install.js
```

## 17. 更新内容

npm 版本发布后不能修改。
需要更新 `a.zip` 时，按以下步骤操作：

1. 准备新的 `a.zip`。
2. 选择新版本，例如 `1.0.1`。
3. 重新切分。
4. 更新全部分片包。
5. 更新加载器包。
6. 更新入口包。
7. 重新发布全部包。
8. 重新验证安装。

不要复用旧版本号。
不要使用 `npm unpublish` 删除旧版本，除非确定没有用户安装。

## 18. 检查清单

发布前：

- [ ] `a.zip` 已准备。
- [ ] 已记录文件大小和 SHA256。
- [ ] 已选择新版本。
- [ ] 分片大小不超过 100 MiB。
- [ ] 分片大小之和等于文件大小。
- [ ] 分片包名唯一。
- [ ] 加载器包依赖全部分片包。
- [ ] 依赖版本精确。
- [ ] 入口包依赖加载器包。
- [ ] `archive.json` 正确。
- [ ] `npm whoami` 正常。
- [ ] 试运行通过。

发布后：

- [ ] 分片包已发布。
- [ ] 加载器包已发布。
- [ ] 入口包已发布。
- [ ] `npm view` 验证通过。
- [ ] 空目录安装成功。
- [ ] SHA256 校验成功。
- [ ] 解压内容存在。

## 19. 快速命令

以下命令只用于示例。
`a.zip` 不存在。
不要直接执行。

```bash
# 1. 检查源文件
wc -c < a.zip
sha256sum a.zip

# 2. 切分文件
# 使用第 8 节的切分脚本

# 3. 检查包内容
npm pack build/chunk-01 --dry-run
npm pack build/loader --dry-run
npm pack build/meta --dry-run

# 4. 试运行
npm publish build/chunk-01 --access public --dry-run
npm publish build/loader --access public --dry-run
npm publish build/meta --access public --dry-run

# 5. 登录
npm login
npm whoami

# 6. 发布分片包
for dir in build/chunk-*; do
  npm publish "$dir" --access public --tag latest || exit 1
done

# 7. 发布加载器包和入口包
npm publish build/loader --access public --tag latest
npm publish build/meta --access public --tag latest

# 8. 验证
npm view @your-scope/a version
mkdir -p a-test
cd a-test
npm init -y
npm install @your-scope/a
```
