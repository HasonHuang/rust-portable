#!/usr/bin/env bash
# Add one official Rust component to an existing installation.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PREFIX="$(dirname -- "$(dirname -- "$SCRIPT_DIR")")"
HELPERS_DIR="$SCRIPT_DIR"

SHA256=""
RUN_DOCTOR=1
PACKAGE=""

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
Usage: add-component.sh [options] <component.tar.xz>

Add an official Rust component to the installed prefix. The component is
installed without network access.

Options:
  --sha256 HASH   Verify the archive with this SHA256 value.
  --skip-doctor   Do not run the self-check after installation.
  -h, --help      Show this help.

Example:
  sudo /opt/rust-portable/share/rust-portable/add-component.sh \
    rust-docs-1.99.1-x86_64-unknown-linux-gnu.tar.xz
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --sha256)
            [ $# -ge 2 ] || die "--sha256 needs a value"
            SHA256="$2"
            shift 2
            ;;
        --sha256=*)
            SHA256="${1#*=}"
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
        -*)
            die "unknown option: $1"
            ;;
        *)
            [ -z "$PACKAGE" ] || die "pass one component archive at a time"
            PACKAGE="$1"
            shift
            ;;
    esac
done

[ -n "$PACKAGE" ] || die "missing component archive; use --help for usage"
[ -f "$PACKAGE" ] || die "file not found: $PACKAGE"
[ -f "$HELPERS_DIR/VERSION" ] || die "this is not a rust-portable installation: $HELPERS_DIR"
[ -x "$PREFIX/bin/rustc" ] || die "missing rustc under $PREFIX"
[ "$(uname -s)" = "Linux" ] || die "this tool supports Linux only"
case "$(uname -m)" in
    x86_64|amd64) ;;
    *) die "this tool supports x86_64 only, got $(uname -m)" ;;
esac

for tool in tar xz sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

INSTALLED_VERSION="$(tr -d '[:space:]' < "$HELPERS_DIR/VERSION")"
[ -n "$INSTALLED_VERSION" ] || die "the installed VERSION file is empty"
case "$(basename -- "$PACKAGE")" in
    *"$INSTALLED_VERSION"*) ;;
    *) warn "the archive name does not contain the installed version $INSTALLED_VERSION" ;;
esac

if [ -n "$SHA256" ]; then
    SHA256="$(printf '%s' "$SHA256" | tr 'A-F' 'a-f')"
    case "$SHA256" in
        *[!0-9a-fA-F]*)
            die "the SHA256 value contains invalid characters"
            ;;
    esac
    [ "${#SHA256}" -eq 64 ] || die "the SHA256 value must contain 64 characters"
    ACTUAL_SHA256="$(sha256sum "$PACKAGE" | awk '{ print $1 }')"
    [ "$ACTUAL_SHA256" = "$SHA256" ] || die "SHA256 mismatch for $PACKAGE"
    log "SHA256 verified"
else
    warn "the archive was not verified; use --sha256 with the official value"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rust-portable-component.XXXXXX")"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log "Extracting $PACKAGE"
tar -xJf "$PACKAGE" -C "$TMP_DIR" || die "cannot extract $PACKAGE"

COMPONENT_DIR="$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[ -n "$COMPONENT_DIR" ] || die "no component directory in $PACKAGE"
[ -f "$COMPONENT_DIR/install.sh" ] || die "no install.sh in $PACKAGE"

log "Installing into $PREFIX"
bash "$COMPONENT_DIR/install.sh" --prefix="$PREFIX" --disable-ldconfig \
    || die "component installation failed"

if [ "$RUN_DOCTOR" -eq 1 ]; then
    log "Running the self-check"
    bash "$HELPERS_DIR/doctor.sh"
fi

log "Component installed. The Rust version was not changed."
