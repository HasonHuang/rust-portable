#!/usr/bin/env bash
# Build the Linux x64 offline installer archive.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION=""
REVISION=""
OUTPUT_DIR="$REPO_ROOT/dist"
PACKAGES_DIR=""
SKIP_DOCTOR=0
KEEP_STAGING=0

log() {
    printf '[build] %s\n' "$*"
}

die() {
    printf '[build] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: scripts/build-linux.sh [options]

Build the Linux x64 offline installer archive.

Options:
  --version VERSION   Rust version. Default: read the VERSION file.
  --revision REV      Optional packaging revision, for example r2.
  --output-dir DIR    Output directory. Default: dist
  --skip-doctor       Do not run the install and self-check test.
  --keep-staging      Keep the staging directory.
  -h, --help          Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || die "--version needs a value"
            VERSION="$2"
            shift 2
            ;;
        --version=*)
            VERSION="${1#*=}"
            shift
            ;;
        --revision)
            [ $# -ge 2 ] || die "--revision needs a value"
            REVISION="$2"
            shift 2
            ;;
        --revision=*)
            REVISION="${1#*=}"
            shift
            ;;
        --output-dir)
            [ $# -ge 2 ] || die "--output-dir needs a value"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#*=}"
            shift
            ;;
        --skip-doctor)
            SKIP_DOCTOR=1
            shift
            ;;
        --keep-staging)
            KEEP_STAGING=1
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

if [ -z "$VERSION" ]; then
    VERSION="$(tr -d '[:space:]' < "$REPO_ROOT/VERSION")"
fi
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid version: $VERSION"
if [ -n "$REVISION" ]; then
    [[ "$REVISION" =~ ^r[0-9]+$ ]] || die "invalid revision: $REVISION. Use r<N>, for example r2."
fi
ASSET_VERSION="$VERSION${REVISION:+-$REVISION}"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd -P)"

if [ -z "$PACKAGES_DIR" ]; then
    PACKAGES_DIR="$REPO_ROOT/build/linux-packages/$VERSION"
fi

REQUIRED=(
    "$REPO_ROOT/linux/install.sh"
    "$REPO_ROOT/linux/env.sh"
    "$REPO_ROOT/linux/doctor.sh"
    "$REPO_ROOT/linux/uninstall.sh"
    "$REPO_ROOT/linux/add-component.sh"
    "$REPO_ROOT/linux/README.md"
    "$REPO_ROOT/shared/tests/smoke.c"
)
for file in "${REQUIRED[@]}"; do
    [ -f "$file" ] || die "missing build input: $file"
done

if [ ! -f "$PACKAGES_DIR/SHA256SUMS" ] \
    || [ -z "$(find "$PACKAGES_DIR" -maxdepth 1 -name '*.tar.xz' -print -quit)" ]; then
    log "Component packages are missing; running prepare-linux.sh"
    bash "$REPO_ROOT/scripts/prepare-linux.sh" \
        --version "$VERSION" --output-dir "$PACKAGES_DIR"
fi

STAGE_ROOT="$OUTPUT_DIR/_stage"
PACKAGE_ROOT="$STAGE_ROOT/rust-portable"
ASSET="$OUTPUT_DIR/rust-portable-v$ASSET_VERSION-linux-x64.tar.gz"
SUMS_PATH="$OUTPUT_DIR/SHA256SUMS.linux"

sha256_of() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{ print $1 }'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{ print $1 }'
    else
        die "sha256sum or shasum is required"
    fi
}

log "Preparing staging directory for v$VERSION"
rm -rf "$STAGE_ROOT"
mkdir -p "$PACKAGE_ROOT"

cp -R "$REPO_ROOT/linux" "$PACKAGE_ROOT/linux"
rm -rf "$PACKAGE_ROOT/linux/packages"
mkdir -p "$PACKAGE_ROOT/linux/packages"
cp "$PACKAGES_DIR"/*.tar.xz "$PACKAGE_ROOT/linux/packages/"
cp "$PACKAGES_DIR/SHA256SUMS" "$PACKAGE_ROOT/linux/packages/SHA256SUMS"

cp -R "$REPO_ROOT/shared" "$PACKAGE_ROOT/shared"
for name in README.md LICENSE CHANGELOG.md; do
    if [ -f "$REPO_ROOT/$name" ]; then
        cp "$REPO_ROOT/$name" "$PACKAGE_ROOT/$name"
    fi
done

printf '%s\n' "$VERSION" > "$PACKAGE_ROOT/VERSION"

(
    cd "$PACKAGE_ROOT/linux/packages"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c SHA256SUMS >/dev/null
    else
        shasum -a 256 -c SHA256SUMS >/dev/null
    fi
) || die "component checksum verification failed"

for package in "$PACKAGE_ROOT"/linux/packages/*.tar.xz; do
    tar -tJf "$package" >/dev/null || die "invalid component archive: $package"
done

GIT_COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
[ -n "$GIT_COMMIT" ] || GIT_COMMIT="unknown"
BUILT_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
BUILDER="$(uname -srm)"
BUILD_GCC="$(gcc --version 2>/dev/null | head -n 1 || true)"
[ -n "$BUILD_GCC" ] || BUILD_GCC="unavailable"
BUILD_GLIBC="$(getconf GNU_LIBC_VERSION 2>/dev/null || true)"
[ -n "$BUILD_GLIBC" ] || BUILD_GLIBC="unavailable"
COMPONENT_LIST="$(cd "$PACKAGE_ROOT/linux/packages" && ls -1 ./*.tar.xz | sed 's|^\./||')"

{
    printf 'rust-portable %s\n' "$ASSET_VERSION"
    printf 'Platform: linux-x64\n'
    printf 'Rust version: %s\n' "$VERSION"
    printf 'Bundle revision: %s\n' "${REVISION:-none}"
    printf 'Built (UTC): %s\n' "$BUILT_AT"
    printf 'Git commit: %s\n' "$GIT_COMMIT"
    printf 'Rust target: x86_64-unknown-linux-gnu\n'
    printf 'Builder: %s\n' "$BUILDER"
    printf 'Build GCC: %s\n' "$BUILD_GCC"
    printf 'Build glibc: %s\n' "$BUILD_GLIBC"
    printf '\nBundled components:\n'
    printf '%s\n' "$COMPONENT_LIST"
} > "$PACKAGE_ROOT/BUILD-INFO.txt"

TEST_ROOT=""
cleanup() {
    if [ -n "$TEST_ROOT" ] && [ -d "$TEST_ROOT" ]; then
        rm -rf "$TEST_ROOT"
    fi
}
trap cleanup EXIT

if [ "$SKIP_DOCTOR" -eq 0 ]; then
    log "Testing the staged installation"
    TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rust-portable-build.XXXXXX")"
    bash "$PACKAGE_ROOT/linux/install.sh" \
        --prefix "$TEST_ROOT/prefix" --no-path --skip-doctor
    bash "$TEST_ROOT/prefix/share/rust-portable/doctor.sh"

    log "Running the example project"
    (
        export PATH="$TEST_ROOT/prefix/bin:$PATH"
        export CARGO_HOME="$TEST_ROOT/cargo-home"
        export CARGO_NET_OFFLINE=true
        cargo run --quiet --manifest-path \
            "$TEST_ROOT/prefix/share/rust-portable/shared/examples/hello/Cargo.toml"
    )
fi

log "Creating the Linux installer archive"
rm -f "$ASSET"
TAR_VERSION="$(tar --version 2>/dev/null | head -n 1 || true)"
case "$TAR_VERSION" in
    *GNU*) GNU_TAR=1 ;;
    *) GNU_TAR=0 ;;
esac
if [ "$GNU_TAR" -eq 1 ]; then
    tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner \
        -C "$STAGE_ROOT" -cf - rust-portable | gzip -9 -n > "$ASSET"
else
    tar -C "$STAGE_ROOT" -cf - rust-portable | gzip -9 -n > "$ASSET"
fi
[ -s "$ASSET" ] || die "the archive is empty"
tar -tzf "$ASSET" >/dev/null || die "the archive is invalid"

HASH="$(sha256_of "$ASSET")"
printf '%s  %s\n' "$HASH" "rust-portable-v$ASSET_VERSION-linux-x64.tar.gz" > "$SUMS_PATH"
SIZE_BYTES="$(wc -c < "$ASSET" | tr -d '[:space:]')"
SIZE_MIB="$(awk -v bytes="$SIZE_BYTES" 'BEGIN { printf "%.1f", bytes / 1048576 }')"

if [ "$KEEP_STAGING" -eq 0 ]; then
    rm -rf "$STAGE_ROOT"
fi

log "Linux package created."
printf '  Version : %s\n' "$VERSION"
if [ -n "$REVISION" ]; then
    printf '  Revision: %s\n' "$REVISION"
fi
printf '  Asset   : %s\n' "$ASSET"
printf '  Size    : %s MiB\n' "$SIZE_MIB"
printf '  SHA256  : %s\n' "$HASH"
printf '  Sums    : %s\n' "$SUMS_PATH"
