#!/usr/bin/env bash
# Test the Linux installer in a RHEL-family container without network access.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
BUNDLE=""
IMAGE="oraclelinux:8"
PLATFORM="linux/amd64"
KEEP_IMAGE=0

log() {
    printf '[test] %s\n' "$*"
}

die() {
    printf '[test] ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: scripts/test-linux-docker.sh --bundle <archive> [options]

Install the Linux archive in a container and run the offline checks.

Options:
  --bundle FILE     Installer archive to test. Required.
  --image IMAGE     Container image. Default: oraclelinux:8
  --platform NAME   Docker platform. Default: linux/amd64
  --keep-image      Keep the test image after the run.
  -h, --help        Show this help.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bundle)
            [ $# -ge 2 ] || die "--bundle needs a file"
            BUNDLE="$2"
            shift 2
            ;;
        --bundle=*)
            BUNDLE="${1#*=}"
            shift
            ;;
        --image)
            [ $# -ge 2 ] || die "--image needs a value"
            IMAGE="$2"
            shift 2
            ;;
        --image=*)
            IMAGE="${1#*=}"
            shift
            ;;
        --platform)
            [ $# -ge 2 ] || die "--platform needs a value"
            PLATFORM="$2"
            shift 2
            ;;
        --platform=*)
            PLATFORM="${1#*=}"
            shift
            ;;
        --keep-image)
            KEEP_IMAGE=1
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

[ -n "$BUNDLE" ] || die "--bundle is required"
[ -f "$BUNDLE" ] || die "file not found: $BUNDLE"
command -v docker >/dev/null 2>&1 || die "docker is required"

BUNDLE="$(cd -- "$(dirname -- "$BUNDLE")" && pwd -P)/$(basename -- "$BUNDLE")"
BUNDLE_DIR="$(dirname -- "$BUNDLE")"
BUNDLE_NAME="$(basename -- "$BUNDLE")"
IMAGE_TAG="rust-portable-test:$(printf '%s' "$IMAGE" | tr -c 'A-Za-z0-9_.-' '_')"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rust-portable-docker.XXXXXX")"
cleanup() {
    rm -rf "$TMP_DIR"
    if [ "$KEEP_IMAGE" -eq 0 ]; then
        docker image rm -f "$IMAGE_TAG" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

log "Building the test image: $IMAGE"
cat > "$TMP_DIR/Dockerfile" <<EOF
FROM $IMAGE
RUN if command -v dnf >/dev/null 2>&1; then \\
        dnf install -y gcc gcc-c++ make tar xz shadow-utils findutils && dnf clean all; \\
    elif command -v microdnf >/dev/null 2>&1; then \\
        microdnf install -y gcc gcc-c++ make tar xz shadow-utils findutils && microdnf clean all; \\
    else \\
        echo "no dnf or microdnf" >&2; exit 1; \\
    fi
RUN useradd -m tester
EOF

docker build --platform "$PLATFORM" -t "$IMAGE_TAG" "$TMP_DIR"

log "Testing a root installation in $IMAGE without network"
docker run --rm --platform "$PLATFORM" --network none \
    -e BUNDLE_NAME="$BUNDLE_NAME" \
    -v "$BUNDLE_DIR:/bundle:ro" \
    "$IMAGE_TAG" \
    bash -c '
        set -euo pipefail

        echo "== extract =="
        mkdir -p /tmp/pkg
        tar -xzf "/bundle/$BUNDLE_NAME" -C /tmp/pkg
        cd /tmp/pkg/rust-portable

        echo "== install as root =="
        bash linux/install.sh --prefix /opt/rust-portable
        . /opt/rust-portable/share/rust-portable/env.sh

        echo "== self-check =="
        /opt/rust-portable/share/rust-portable/doctor.sh

        echo "== example =="
        CARGO_NET_OFFLINE=true cargo run --quiet \
            --manifest-path /opt/rust-portable/share/rust-portable/shared/examples/hello/Cargo.toml

        echo "== add a component =="
        bash /opt/rust-portable/share/rust-portable/add-component.sh --skip-doctor \
            /tmp/pkg/rust-portable/linux/packages/rustfmt-*.tar.xz
        /opt/rust-portable/share/rust-portable/doctor.sh >/dev/null

        echo "== uninstall =="
        bash /opt/rust-portable/share/rust-portable/uninstall.sh --yes
        test ! -e /opt/rust-portable
        test ! -e /etc/profile.d/rust-portable.sh
        echo "root test passed"
    '

log "Testing a user installation in $IMAGE without network"
docker run --rm --platform "$PLATFORM" --network none \
    -u tester -e HOME=/home/tester -e USER=tester -e SHELL=/bin/bash \
    -e BUNDLE_NAME="$BUNDLE_NAME" \
    -v "$BUNDLE_DIR:/bundle:ro" \
    "$IMAGE_TAG" \
    bash -c '
        set -euo pipefail

        echo "== extract =="
        mkdir -p /tmp/pkg
        tar -xzf "/bundle/$BUNDLE_NAME" -C /tmp/pkg
        cd /tmp/pkg/rust-portable

        echo "== install as user =="
        bash linux/install.sh

        echo "== check shell configuration =="
        grep -q "rust-portable" "$HOME/.bashrc"
        . "$HOME/.local/rust-portable/share/rust-portable/env.sh"
        rustc --version

        echo "== example =="
        CARGO_NET_OFFLINE=true cargo run --quiet \
            --manifest-path "$HOME/.local/rust-portable/share/rust-portable/shared/examples/hello/Cargo.toml"

        echo "== uninstall =="
        bash "$HOME/.local/rust-portable/share/rust-portable/uninstall.sh" --yes
        test ! -e "$HOME/.local/rust-portable"
        ! grep -q ">>> rust-portable >>>" "$HOME/.bashrc"
        echo "user test passed"
    '

log "All offline container tests passed."
