#!/usr/bin/env bash
# Install the bundled Rust components without network access.
set -euo pipefail
umask 022

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BUNDLE_ROOT="$(dirname -- "$SCRIPT_DIR")"
PACKAGES_DIR="$SCRIPT_DIR/packages"
VERSION_FILE="$BUNDLE_ROOT/VERSION"

PREFIX=""
CONFIGURE_PATH=1
INSTALL_DEPS=0
FORCE=0
RUN_DOCTOR=1

log() {
    printf '[rust-portable] %s\n' "$*"
}

warn() {
    printf '[rust-portable] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[rust-portable] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: linux/install.sh [options]

Install the bundled Rust toolchain. The installation is offline.

Options:
  --prefix DIR     Install to DIR. Default: /opt/rust-portable for root,
                   $HOME/.local/rust-portable for a normal user.
  --no-path        Do not change /etc/profile.d or user shell files.
  --install-deps   Install gcc, g++, make, tar and xz when missing.
  --force          Allow a non-empty prefix or a different installed version.
  --skip-doctor    Do not run the self-check after installation.
  -h, --help       Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            [ $# -ge 2 ] || die "--prefix needs a directory"
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#*=}"
            shift
            ;;
        --no-path)
            CONFIGURE_PATH=0
            shift
            ;;
        --install-deps)
            INSTALL_DEPS=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --skip-doctor)
            RUN_DOCTOR=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

[ "$(uname -s)" = "Linux" ] || die "this installer supports Linux only"
case "$(uname -m)" in
    x86_64|amd64) ;;
    *) die "this installer supports x86_64 only, got $(uname -m)" ;;
esac

GLIBC_VERSION="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{ print $2 }')"
if [ -n "$GLIBC_VERSION" ]; then
    OLDEST="$(printf '%s\n%s\n' "2.17" "$GLIBC_VERSION" | LC_ALL=C sort -V | head -n 1)"
    [ "$OLDEST" = "2.17" ] || die "glibc $GLIBC_VERSION is too old; Rust needs glibc 2.17 or newer"
else
    warn "cannot detect the glibc version; Rust needs glibc 2.17 or newer"
fi

[ -f "$VERSION_FILE" ] || die "missing file: $VERSION_FILE"
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid VERSION: $VERSION"

for file in env.sh doctor.sh uninstall.sh add-component.sh README.md; do
    [ -f "$SCRIPT_DIR/$file" ] || die "the package is incomplete: missing linux/$file"
done
[ -f "$BUNDLE_ROOT/shared/tests/smoke.c" ] || die "the package is incomplete: missing shared/tests/smoke.c"
[ -f "$PACKAGES_DIR/SHA256SUMS" ] || die "the package is incomplete: missing linux/packages/SHA256SUMS"
set -- "$PACKAGES_DIR"/*.tar.xz
[ -e "$1" ] || die "the package is incomplete: no component archives in linux/packages"
set --

MISSING_DEPS=""
for tool in gcc g++ make tar xz; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_DEPS="${MISSING_DEPS:+$MISSING_DEPS }$tool"
    fi
done
if [ -n "$MISSING_DEPS" ]; then
    if command -v dnf >/dev/null 2>&1; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PACKAGE_MANAGER="yum"
    else
        PACKAGE_MANAGER=""
    fi

    if [ "$INSTALL_DEPS" -eq 1 ]; then
        [ -n "$PACKAGE_MANAGER" ] || die "cannot find dnf or yum; install gcc, g++, make, tar and xz manually"
        log "Installing tools: gcc gcc-c++ make tar xz"
        if [ "$(id -u)" -eq 0 ]; then
            "$PACKAGE_MANAGER" install -y gcc gcc-c++ make tar xz
        elif command -v sudo >/dev/null 2>&1; then
            sudo "$PACKAGE_MANAGER" install -y gcc gcc-c++ make tar xz
        else
            die "run as root, or install gcc, g++, make, tar and xz manually"
        fi
    else
        warn "missing tools: $MISSING_DEPS"
        if [ -n "$PACKAGE_MANAGER" ]; then
            warn "install them with: sudo $PACKAGE_MANAGER install -y gcc gcc-c++ make tar xz"
        else
            warn "install gcc, g++, make, tar and xz with your package manager"
        fi
    fi
fi

for tool in tar xz sha256sum; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        case "$tool" in
            sha256sum) PACKAGE_HINT="coreutils" ;;
            *) PACKAGE_HINT="tar xz" ;;
        esac
        die "missing required tool: $tool. Install it with: sudo dnf install -y $PACKAGE_HINT"
    fi
done

if [ -z "$PREFIX" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        PREFIX="/opt/rust-portable"
    else
        [ -n "${HOME:-}" ] || die "HOME is not set; use --prefix"
        PREFIX="$HOME/.local/rust-portable"
    fi
fi

case "$PREFIX" in
    "~") [ -n "${HOME:-}" ] || die "HOME is not set; use an absolute --prefix"
         PREFIX="$HOME" ;;
    "~/"*) [ -n "${HOME:-}" ] || die "HOME is not set; use an absolute --prefix"
           PREFIX="$HOME/${PREFIX#~/}" ;;
esac
case "$PREFIX" in
    /*) ;;
    *) die "--prefix must be an absolute path: $PREFIX" ;;
esac
case "$PREFIX" in
    *[[:space:]]*) die "the prefix must not contain spaces: $PREFIX" ;;
esac
while [ "${PREFIX%/}" != "$PREFIX" ]; do
    PREFIX="${PREFIX%/}"
done
[ -n "$PREFIX" ] || PREFIX="/"
[ "$PREFIX" != "/" ] || die "refusing to install to /"

HELPERS_DIR="$PREFIX/share/rust-portable"
MARKER="$HELPERS_DIR/VERSION"
INSTALLED_VERSION=""
if [ -f "$MARKER" ]; then
    INSTALLED_VERSION="$(tr -d '[:space:]' < "$MARKER")"
fi

if [ -e "$PREFIX" ] && [ ! -d "$PREFIX" ]; then
    die "the prefix exists and is not a directory: $PREFIX"
fi
if [ -d "$PREFIX" ] && [ -n "$(ls -A "$PREFIX" 2>/dev/null)" ]; then
    if [ -z "$INSTALLED_VERSION" ] && [ "$FORCE" -ne 1 ]; then
        die "the prefix is not empty and is not a rust-portable installation: $PREFIX. Use --force or another --prefix."
    fi
    if [ -n "$INSTALLED_VERSION" ] && [ "$INSTALLED_VERSION" != "$VERSION" ] && [ "$FORCE" -ne 1 ]; then
        die "the prefix contains rust-portable $INSTALLED_VERSION; use --force to replace it with $VERSION."
    fi
fi

PROBE="$PREFIX"
while [ ! -d "$PROBE" ]; do
    PROBE="$(dirname -- "$PROBE")"
done
AVAILABLE_KB="$(df -Pk "$PROBE" 2>/dev/null | awk 'NR == 2 { print $4 }')"
if [ -n "$AVAILABLE_KB" ] && [ "$AVAILABLE_KB" -lt 2097152 ]; then
    die "not enough free space in $PROBE; at least 2 GiB is required"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rust-portable-install.XXXXXX")"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log "Verifying component packages"
(
    cd "$PACKAGES_DIR"
    sha256sum -c SHA256SUMS >/dev/null
) || die "component checksum verification failed"

for package in "$PACKAGES_DIR"/*.tar.xz; do
    package_name="$(basename -- "$package")"
    awk -v name="$package_name" '$2 == name { found = 1 } END { exit(found ? 0 : 1) }' \
        "$PACKAGES_DIR/SHA256SUMS" \
        || die "package is not listed in SHA256SUMS: $package_name"
done

log "Installing Rust $VERSION to $PREFIX"
mkdir -p "$PREFIX"

for package in "$PACKAGES_DIR"/*.tar.xz; do
    package_name="$(basename -- "$package" .tar.xz)"
    log "Installing component: $package_name"

    COMPONENT_TMP="$TMP_DIR/$package_name"
    mkdir -p "$COMPONENT_TMP"
    tar -xJf "$package" -C "$COMPONENT_TMP" || die "cannot extract $package"

    COMPONENT_DIR="$(find "$COMPONENT_TMP" -mindepth 1 -maxdepth 1 -type d -print -quit)"
    [ -n "$COMPONENT_DIR" ] || die "no component directory in $package"
    [ -f "$COMPONENT_DIR/install.sh" ] || die "no install.sh in $package"

    bash "$COMPONENT_DIR/install.sh" --prefix="$PREFIX" --disable-ldconfig \
        || die "component installation failed: $package_name"
    rm -rf "$COMPONENT_TMP"
done

log "Installing helper files"
mkdir -p "$HELPERS_DIR"
cp -f "$SCRIPT_DIR/env.sh" "$HELPERS_DIR/env.sh"
cp -f "$SCRIPT_DIR/doctor.sh" "$HELPERS_DIR/doctor.sh"
cp -f "$SCRIPT_DIR/uninstall.sh" "$HELPERS_DIR/uninstall.sh"
cp -f "$SCRIPT_DIR/add-component.sh" "$HELPERS_DIR/add-component.sh"
cp -f "$SCRIPT_DIR/README.md" "$HELPERS_DIR/README-linux.md"
cp -f "$VERSION_FILE" "$HELPERS_DIR/VERSION"
for name in BUILD-INFO.txt README.md LICENSE CHANGELOG.md; do
    if [ -f "$BUNDLE_ROOT/$name" ]; then
        cp -f "$BUNDLE_ROOT/$name" "$HELPERS_DIR/$name"
    fi
done
rm -rf "$HELPERS_DIR/shared"
cp -R "$BUNDLE_ROOT/shared" "$HELPERS_DIR/shared"
chmod 755 "$HELPERS_DIR/env.sh" "$HELPERS_DIR/doctor.sh" \
    "$HELPERS_DIR/uninstall.sh" "$HELPERS_DIR/add-component.sh"

ACTUAL_VERSION="$("$PREFIX/bin/rustc" --version 2>/dev/null | awk '{ print $2 }')" \
    || die "cannot run $PREFIX/bin/rustc"
[ "$ACTUAL_VERSION" = "$VERSION" ] \
    || die "rustc reports $ACTUAL_VERSION, expected $VERSION"

remove_shell_block() {
    local file="$1"
    [ -f "$file" ] || return 0
    local temp_file
    temp_file="$(mktemp "${TMPDIR:-/tmp}/rust-portable-rc.XXXXXX")"
    awk '
        /^# >>> rust-portable >>>$/ { skip = 1; next }
        /^# <<< rust-portable <<<$/ { skip = 0; next }
        !skip { print }
    ' "$file" > "$temp_file"
    cat "$temp_file" > "$file"
    rm -f "$temp_file"
}

configure_user_shell() {
    local shell_name rc
    local -a shell_files=()
    [ -n "${HOME:-}" ] || die "HOME is not set; use --no-path"
    shell_name="$(basename -- "${SHELL:-/bin/bash}")"
    case "$shell_name" in
        zsh) shell_files=("$HOME/.zshrc") ;;
        bash) shell_files=("$HOME/.bashrc" "$HOME/.bash_profile") ;;
        *) shell_files=("$HOME/.profile") ;;
    esac

    for rc in "${shell_files[@]}"; do
        touch "$rc" || die "cannot write $rc"
        remove_shell_block "$rc"
        {
            printf '\n# >>> rust-portable >>>\n'
            printf 'if [ -r "%s" ]; then\n' "$HELPERS_DIR/env.sh"
            printf '    . "%s"\n' "$HELPERS_DIR/env.sh"
            printf 'fi\n'
            printf '# <<< rust-portable <<<\n'
        } >> "$rc"
        log "Updated $rc"
    done
}

if [ "$CONFIGURE_PATH" -eq 1 ]; then
    if [ "$(id -u)" -eq 0 ]; then
        PROFILE_FILE="/etc/profile.d/rust-portable.sh"
        if [ -f "$PROFILE_FILE" ] && ! grep -q "Generated by rust-portable" "$PROFILE_FILE"; then
            cp -f "$PROFILE_FILE" "$PROFILE_FILE.bak"
            warn "backed up the old $PROFILE_FILE to $PROFILE_FILE.bak"
        fi
        {
            printf '# Generated by rust-portable. Do not edit.\n'
            printf 'if [ -r "%s" ]; then\n' "$HELPERS_DIR/env.sh"
            printf '    . "%s"\n' "$HELPERS_DIR/env.sh"
            printf 'fi\n'
        } > "$PROFILE_FILE"
        chmod 644 "$PROFILE_FILE"
        log "Updated $PROFILE_FILE"
    else
        configure_user_shell
    fi
fi

echo
log "Rust $VERSION installed."
printf '  Prefix:   %s\n' "$PREFIX"
printf '  Activate: . "%s"\n' "$HELPERS_DIR/env.sh"
printf '  Check:    "%s"\n' "$HELPERS_DIR/doctor.sh"

if [ "$RUN_DOCTOR" -eq 1 ]; then
    log "Running the self-check"
    bash "$HELPERS_DIR/doctor.sh"
fi

echo
log "Done. Open a new terminal, or source env.sh now."
