#!/usr/bin/env bash
# Check the installed Rust environment. This script does not use the network.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PREFIX="$(dirname -- "$(dirname -- "$SCRIPT_DIR")")"
HELPERS_DIR="$PREFIX/share/rust-portable"
SHARED_DIR="$HELPERS_DIR/shared"
VERSION_FILE="$HELPERS_DIR/VERSION"

FAIL=0

fail_check() {
    printf '[rust-portable] FAILED: %s\n' "$*" >&2
    FAIL=1
}

run_check() {
    local name="$1"
    shift

    printf '[check] %s\n' "$name"
    if ! "$@"; then
        fail_check "$name"
    fi
}

if [ ! -x "$PREFIX/bin/rustc" ]; then
    printf '[rust-portable] ERROR: rustc was not found: %s\n' "$PREFIX/bin/rustc" >&2
    printf '[rust-portable] Install the Linux package, or use the correct prefix.\n' >&2
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    printf '[rust-portable] ERROR: missing version file: %s\n' "$VERSION_FILE" >&2
    exit 1
fi

export PATH="$PREFIX/bin:$PATH"

echo "============================================================"
echo " Rust Portable - Linux environment check"
echo "============================================================"
echo " Package     : $PREFIX"
echo " Shared      : $SHARED_DIR"
echo " Target      : x86_64-unknown-linux-gnu"
echo "============================================================"
echo

run_check "rustc" rustc --version
run_check "cargo" cargo --version
run_check "rustfmt" rustfmt --version
run_check "clippy" cargo clippy --version
run_check "rust-analyzer" rust-analyzer --version
run_check "gcc" gcc --version
run_check "g++" g++ --version
run_check "make" make --version

echo
echo "[check] rust host"
HOST="$(rustc -vV 2>/dev/null | awk '/^host:/ { print $2 }')" || HOST=""
if [ "$HOST" != "x86_64-unknown-linux-gnu" ]; then
    fail_check "rust host is '$HOST', expected 'x86_64-unknown-linux-gnu'"
else
    echo "x86_64-unknown-linux-gnu"
fi

echo "[check] rust version"
ACTUAL_VERSION="$(rustc --version 2>/dev/null | awk '{ print $2 }')" || ACTUAL_VERSION=""
EXPECTED_VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
    fail_check "rustc reports $ACTUAL_VERSION, expected $EXPECTED_VERSION"
else
    echo "$ACTUAL_VERSION"
fi

echo
echo "[check] shared files"
for file in "$SHARED_DIR/examples/hello/Cargo.toml" "$SHARED_DIR/tests/smoke.c"; do
    if [ ! -f "$file" ]; then
        fail_check "missing $file"
    fi
done

# Build and run the temporary programs outside /tmp when possible.
# Some hardened systems mount /tmp with noexec.
DOCTOR_BASE="${HOME:-}"
if [ -n "$DOCTOR_BASE" ] \
    && mkdir -p "$DOCTOR_BASE/.cache/rust-portable" 2>/dev/null \
    && TMP_DIR="$(mktemp -d "$DOCTOR_BASE/.cache/rust-portable/doctor.XXXXXX" 2>/dev/null)"; then
    :
else
    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rust-portable-doctor.XXXXXX")"
fi
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Use a temporary Cargo home so the check does not touch the user cache.
export CARGO_HOME="$TMP_DIR/cargo-home"
export CARGO_NET_OFFLINE=true
mkdir -p "$CARGO_HOME"

echo
echo "[check] building a temporary Rust project..."
if ! cargo new --quiet --vcs none --name doctor "$TMP_DIR/doctor"; then
    fail_check "cargo new"
elif ! (cd "$TMP_DIR/doctor" && cargo run --quiet); then
    fail_check "cargo run"
fi

echo "[check] compiling a temporary C program..."
if ! gcc "$SHARED_DIR/tests/smoke.c" -o "$TMP_DIR/smoke"; then
    fail_check "C compile"
elif ! "$TMP_DIR/smoke"; then
    fail_check "C run"
fi

echo
if [ "$FAIL" -ne 0 ]; then
    echo "[rust-portable] One or more checks failed."
    if ! command -v gcc >/dev/null 2>&1 \
        || ! command -v g++ >/dev/null 2>&1 \
        || ! command -v make >/dev/null 2>&1; then
        if command -v dnf >/dev/null 2>&1; then
            echo "[rust-portable] Install the build tools: sudo dnf install -y gcc gcc-c++ make"
        elif command -v yum >/dev/null 2>&1; then
            echo "[rust-portable] Install the build tools: sudo yum install -y gcc gcc-c++ make"
        else
            echo "[rust-portable] Install gcc, g++, and make with your package manager."
        fi
    fi
    exit 1
fi

echo "[rust-portable] All checks passed."
