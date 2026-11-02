# Linux x64 离线安装包

本目录包含 Linux x64 的离线安装脚本。
Release 包还包含 Rust 官方组件包。
Git 仓库不包含组件包。

安装包用于没有外网的 RHEL 系系统。
组件安装和自检不需要网络。
系统依赖由本机软件仓库安装。

修订包的文件名包含 `-r<N>`，例如 `rust-portable-v1.99.1-r2-linux-x64.tar.gz`。
包内 Rust 版本仍是 `1.99.1`。

## 1. 适用平台

- Linux x64（`x86_64`）。
- RHEL 系发行版：RHEL、CentOS、Rocky、AlmaLinux、Oracle Linux、openEuler、麒麟。
- glibc 2.17 或更新。
- Linux kernel 3.2 或更新。
- 验证环境：Oracle Linux 8.10（离线安装和组件运行）。

本包不使用 rustup。
它直接安装 Rust 官方独立组件。
工具链安装在独立前缀中。

## 2. 系统依赖

安装 Rust 不需要 C 编译器。
编译 Rust 程序需要 C 编译器和链接器。

执行以下命令安装依赖：

```bash
sudo dnf install -y gcc gcc-c++ make
```

旧系统可以使用 `yum`：

```bash
sudo yum install -y gcc gcc-c++ make
```

`install.sh` 还需要 `tar` 和 `xz`。
最小系统请一并安装：

```bash
sudo dnf install -y tar xz
```

`install.sh --install-deps` 可以自动执行上述命令。
普通用户需要 `sudo` 权限。

## 3. 安装

解压安装包：

```bash
tar -xzf rust-portable-v<version>-linux-x64.tar.gz
cd rust-portable
```

### 3.1 系统级安装

root 用户运行：

```bash
sudo linux/install.sh
```

默认前缀：`/opt/rust-portable`。

### 3.2 用户级安装

普通用户运行：

```bash
linux/install.sh
```

默认前缀：`~/.local/rust-portable`。

### 3.3 指定前缀

```bash
sudo linux/install.sh --prefix /data/rust
```

前缀必须是绝对路径。
前缀不能包含空格。

### 3.4 安装参数

| 参数 | 说明 |
| --- | --- |
| `--prefix DIR` | 指定安装目录 |
| `--no-path` | 不修改 shell 配置 |
| `--install-deps` | 用 dnf/yum 安装 gcc、g++、make、tar、xz |
| `--force` | 允许非空前缀或不同版本 |
| `--skip-doctor` | 安装后不运行自检 |
| `--help` | 显示帮助 |

> `rust-src` 包含标准库源码，安装时文件较多，需要一些时间。

`install.sh` 会执行以下动作：

1. 校验系统和 glibc 版本。
2. 校验组件包的 SHA256。
3. 把组件安装到前缀。
4. 安装脚本和 `shared/` 到前缀。
5. 校验 `rustc --version` 等于包内 `VERSION`。
6. 配置 PATH。
7. 运行 `doctor.sh`。

## 4. 激活环境

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

`env.sh` 可以重复执行。
它不会重复添加 PATH。

## 5. 自检

```bash
/opt/rust-portable/share/rust-portable/doctor.sh
```

自检检查以下内容：

- rustc、cargo、rustfmt、clippy、rust-analyzer。
- gcc、g++、make。
- Rust host 为 `x86_64-unknown-linux-gnu`。
- 临时 Rust 项目可以离线编译和运行。
- `shared/tests/smoke.c` 可以编译和运行。

## 6. 验证示例

```bash
cargo run --manifest-path /opt/rust-portable/share/rust-portable/shared/examples/hello/Cargo.toml
```

预期输出：

```text
Hello from the portable Rust environment!
Toolchain: linux / x86_64
```

## 7. 组件

安装包包含以下组件：

- rustc
- cargo
- rust-std
- rustfmt
- clippy
- rust-analyzer
- rust-src

安装包不包含：

- rust-docs
- llvm-tools
- rust-analysis
- rustc-dev

## 8. 补装组件

使用已安装的 `add-component.sh`：

```bash
sudo /opt/rust-portable/share/rust-portable/add-component.sh \
  /path/to/rust-docs-1.99.1-x86_64-unknown-linux-gnu.tar.xz
```

建议用 `--sha256` 校验组件包：

```bash
sudo /opt/rust-portable/share/rust-portable/add-component.sh \
  --sha256 <sha256> \
  /path/to/rust-docs-1.99.1-x86_64-unknown-linux-gnu.tar.xz
```

组件包来自官方地址或内网镜像：

```text
https://static.rust-lang.org/dist/
```

补装组件不改变 Rust 版本。

## 9. 升级

安装新的 Rust 版本：

```bash
sudo linux/install.sh --prefix /opt/rust-portable --force
```

同一 Rust 版本新增组件时，直接重跑新的安装包：

```bash
sudo linux/install.sh --prefix /opt/rust-portable
```

官方组件安装器是幂等的。
它会更新已有组件。

## 10. 卸载

```bash
sudo /opt/rust-portable/share/rust-portable/uninstall.sh --yes
```

卸载脚本执行以下动作：

- 删除 `/etc/profile.d/rust-portable.sh` 或用户 shell 配置块。
- 删除安装前缀。
- 保留 `~/.cargo`。

当前终端需要打开新终端，或手动删除旧 PATH。

## 11. 离线说明

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

## 12. 目录结构

安装后的目录：

```text
<prefix>/
├─ bin/                     # rustc、cargo、rustfmt、rust-analyzer
├─ lib/                     # 标准库和 rustlib 清单
├─ share/
│  ├─ rust-portable/
│  │  ├─ env.sh
│  │  ├─ doctor.sh
│  │  ├─ uninstall.sh
│  │  ├─ add-component.sh
│  │  ├─ README-linux.md
│  │  ├─ README.md
│  │  ├─ LICENSE
│  │  ├─ CHANGELOG.md
│  │  ├─ VERSION
│  │  ├─ BUILD-INFO.txt
│  │  └─ shared/
│  └─ doc/                  # Rust 组件自带文档和许可证
└─ ...
```

## 13. 常见问题

**`rustc` 命令不存在**

打开新终端。
或执行 `source <prefix>/share/rust-portable/env.sh`。

**`gcc` 或 `linker` 找不到**

安装系统依赖：

```bash
sudo dnf install -y gcc gcc-c++ make
```

**安装时提示空间不足**

安装后约 1.3 GB。
请清理前缀所在文件系统。

**`/tmp` 为 noexec**

安装脚本用 `bash <path>` 执行安装器。
它不要求 `/tmp` 可执行。
`doctor.sh` 在 `$HOME/.cache/rust-portable` 下编译和运行临时程序。

**SELinux 拒绝执行**

在 RHEL 系系统上，可以尝试：

```bash
sudo restorecon -R /opt/rust-portable
```

**需要标准库文档**

补装 `rust-docs`：

```bash
sudo /opt/rust-portable/share/rust-portable/add-component.sh \
  rust-docs-1.99.1-x86_64-unknown-linux-gnu.tar.xz
```

文档位于 `<prefix>/share/doc/rust/html/index.html`。

**有多个安装前缀**

用户 shell 配置只保留最后一次安装的 PATH 块。
系统级安装使用 `/etc/profile.d/rust-portable.sh`。
建议每台机器只保留一个系统级安装。
