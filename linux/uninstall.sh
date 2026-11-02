#!/usr/bin/env bash
# Remove a rust-portable Linux installation. User Cargo caches are kept.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PREFIX="$(dirname -- "$(dirname -- "$SCRIPT_DIR")")"
HELPERS_DIR="$SCRIPT_DIR"
ENV_FILE="$HELPERS_DIR/env.sh"

ASSUME_YES=0

log() {
    printf '[rust-portable] %s\n' "$*"
}

die() {
    printf '[rust-portable] ERROR: %s\n' "$*" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)
            ASSUME_YES=1
            shift
            ;;
        -h|--help)
            cat <<'EOF'
Usage: uninstall.sh [--yes]

Remove the rust-portable installation that owns this script.
  --yes, -y   Do not ask for confirmation.
EOF
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

[ -n "$PREFIX" ] || die "cannot determine the prefix"
[ "$PREFIX" != "/" ] || die "refusing to remove /"
[ -n "${HOME:-}" ] && [ "$PREFIX" != "$HOME" ] || die "refusing to remove the home directory"
case "$PREFIX" in
    /*) ;;
    *) die "the prefix is not absolute: $PREFIX" ;;
esac
[ -f "$HELPERS_DIR/VERSION" ] || die "this is not a rust-portable installation: $HELPERS_DIR"
[ -x "$PREFIX/bin/rustc" ] || die "missing rustc under $PREFIX"

if [ "$ASSUME_YES" -ne 1 ]; then
    printf '[rust-portable] Remove %s? [y/N] ' "$PREFIX"
    read -r answer
    case "$answer" in
        y|Y) ;;
        *) log "Cancelled."; exit 0 ;;
    esac
fi

if [ -f /etc/profile.d/rust-portable.sh ] \
    && grep -qF "$ENV_FILE" /etc/profile.d/rust-portable.sh; then
    rm -f /etc/profile.d/rust-portable.sh
    log "Removed /etc/profile.d/rust-portable.sh"
fi

remove_user_block() {
    local file="$1"
    [ -f "$file" ] || return 0
    grep -qF "$ENV_FILE" "$file" || return 0

    local temp_file
    temp_file="$(mktemp "${TMPDIR:-/tmp}/rust-portable-rc.XXXXXX")"
    awk -v needle="$ENV_FILE" '
        /^# >>> rust-portable >>>$/ { inblock = 1; block = $0 ORS; next }
        /^# <<< rust-portable <<<$/ {
            inblock = 0
            block = block $0 ORS
            if (index(block, needle) == 0) {
                printf "%s", block
            }
            block = ""
            next
        }
        inblock { block = block $0 ORS; next }
        { print }
        END { if (inblock) printf "%s", block }
    ' "$file" > "$temp_file"
    cat "$temp_file" > "$file"
    rm -f "$temp_file"
    log "Cleaned $file"
}

if [ -n "${HOME:-}" ]; then
    for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
        remove_user_block "$rc"
    done
fi

log "Removing $PREFIX"
rm -rf -- "$PREFIX"

log "The installation was removed."
log "Open a new terminal to update PATH."
log "The Cargo cache in ~/.cargo was NOT removed."
