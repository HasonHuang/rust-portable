#!/usr/bin/env bash
# Download and verify the official Rust components for the Linux package.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
VERSION=""
DIST_SERVER="https://static.rust-lang.org"
OUTPUT_DIR=""
TARGET_HOST="x86_64-unknown-linux-gnu"

COMPONENT_NAMES=(
    rustc
    cargo
    rust-std
    rust-src
    rustfmt-preview
    clippy-preview
    rust-analyzer-preview
)

log() {
    printf '[prepare] %s\n' "$*"
}

warn() {
    printf '[prepare] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[prepare] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: scripts/prepare-linux.sh [options]

Download and verify the official Rust components for Linux x64.

Options:
  --version VERSION    Rust version. Default: read the VERSION file.
  --dist-server URL    Rust distribution server.
                       Default: https://static.rust-lang.org
  --output-dir DIR     Download directory.
                       Default: build/linux-packages/<version>
  -h, --help           Show this help.
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
        --dist-server)
            [ $# -ge 2 ] || die "--dist-server needs a value"
            DIST_SERVER="$2"
            shift 2
            ;;
        --dist-server=*)
            DIST_SERVER="${1#*=}"
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
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid Rust version: $VERSION"

if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$REPO_ROOT/build/linux-packages/$VERSION"
fi
mkdir -p "$OUTPUT_DIR"

DIST_SERVER="${DIST_SERVER%/}"

command -v curl >/dev/null 2>&1 || die "curl is required"
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    die "Python 3.11 or newer is required (tomllib)"
fi

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

download() {
    local url="$1"
    local destination="$2"

    curl -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 1800 \
        -o "$destination" "$url"
}

MANIFEST_NAME="channel-rust-$VERSION.toml"
MANIFEST_URL="$DIST_SERVER/dist/$MANIFEST_NAME"
MANIFEST_PATH="$OUTPUT_DIR/$MANIFEST_NAME"
MANIFEST_SUM_PATH="$MANIFEST_PATH.sha256"

log "Fetching the Rust $VERSION manifest"
download "$MANIFEST_URL.sha256" "$MANIFEST_SUM_PATH.part"
EXPECTED_MANIFEST_SHA="$(awk 'NR == 1 { print $1 }' "$MANIFEST_SUM_PATH.part")"
[ "${#EXPECTED_MANIFEST_SHA}" -eq 64 ] || die "cannot read the manifest checksum"
mv -f "$MANIFEST_SUM_PATH.part" "$MANIFEST_SUM_PATH"

if [ -f "$MANIFEST_PATH" ] && [ "$(sha256_of "$MANIFEST_PATH")" = "$EXPECTED_MANIFEST_SHA" ]; then
    log "Using the cached manifest"
else
    log "Downloading $MANIFEST_NAME"
    download "$MANIFEST_URL" "$MANIFEST_PATH.part"
    ACTUAL_MANIFEST_SHA="$(sha256_of "$MANIFEST_PATH.part")"
    [ "$ACTUAL_MANIFEST_SHA" = "$EXPECTED_MANIFEST_SHA" ] \
        || die "manifest checksum mismatch"
    mv -f "$MANIFEST_PATH.part" "$MANIFEST_PATH"
fi

COMPONENTS_FILE="$OUTPUT_DIR/components.tsv"
python3 - "$MANIFEST_PATH" "$TARGET_HOST" "${COMPONENT_NAMES[@]}" > "$COMPONENTS_FILE" <<'PY'
import sys
import tomllib

manifest_path = sys.argv[1]
target = sys.argv[2]
names = sys.argv[3:]

with open(manifest_path, "rb") as handle:
    manifest = tomllib.load(handle)

for name in names:
    package = manifest.get("pkg", {}).get(name)
    if package is None:
        raise SystemExit(f"package {name} is not in the manifest")

    targets = package.get("target", {})
    key = "*" if name == "rust-src" else target
    entry = targets.get(key)
    if entry is None:
        raise SystemExit(f"package {name} has no target {key}")

    url = entry.get("xz_url")
    digest = entry.get("xz_hash")
    if not url or not digest:
        raise SystemExit(f"package {name} has no xz artifact")

    print(f"{name}\t{url}\t{digest}")
PY

SUMS_TMP="$OUTPUT_DIR/SHA256SUMS.tmp"
: > "$SUMS_TMP"

COUNT=0
while IFS=$'\t' read -r name url digest; do
    [ -n "$name" ] || continue

    if [ "$DIST_SERVER" != "https://static.rust-lang.org" ]; then
        case "$url" in
            */dist/*) url="$DIST_SERVER/dist/${url#*/dist/}" ;;
        esac
    fi

    filename="${url##*/}"
    destination="$OUTPUT_DIR/$filename"
    log "Checking $filename"

    if [ -f "$destination" ] && [ "$(sha256_of "$destination")" = "$digest" ]; then
        log "  cached"
    else
        log "  downloading"
        rm -f "$destination.part"
        download "$url" "$destination.part"
        actual="$(sha256_of "$destination.part")"
        if [ "$actual" != "$digest" ]; then
            rm -f "$destination.part"
            die "checksum mismatch for $filename"
        fi
        mv -f "$destination.part" "$destination"
    fi

    printf '%s  %s\n' "$digest" "$filename" >> "$SUMS_TMP"
    COUNT=$((COUNT + 1))
done < "$COMPONENTS_FILE"

[ "$COUNT" -gt 0 ] || die "no components were downloaded"
LC_ALL=C sort -k 2 "$SUMS_TMP" > "$OUTPUT_DIR/SHA256SUMS"
rm -f "$SUMS_TMP" "$COMPONENTS_FILE"

log "Rust $VERSION components are ready."
log "  Directory: $OUTPUT_DIR"
log "  Components: $COUNT"
log "  Checksums: $OUTPUT_DIR/SHA256SUMS"
