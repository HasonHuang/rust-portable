# Activate the installed Rust environment in the CURRENT shell.
# Usage: . /opt/rust-portable/share/rust-portable/env.sh

# Detect the path of this file when sourced from bash or zsh.
if [ -n "${ZSH_VERSION:-}" ]; then
    eval '_rust_portable_self="${(%):-%x}"'
else
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" = "$0" ]; then
        printf '[rust-portable] Source this file: . "%s"\n' "${BASH_SOURCE[0]}" >&2
        exit 1
    fi
    _rust_portable_self="${BASH_SOURCE[0]:-$0}"
fi

# Helpers live in share/rust-portable under the install prefix.
_rust_portable_dir="$(cd -- "$(dirname -- "$_rust_portable_self")" && pwd -P)"
RUST_PORTABLE_HOME="$(dirname -- "$(dirname -- "$_rust_portable_dir")")"
RUST_PORTABLE_SHARED="$RUST_PORTABLE_HOME/share/rust-portable/shared"
export RUST_PORTABLE_HOME
export RUST_PORTABLE_SHARED

# Do not add the same directory more than once.
case ":${PATH:-}:" in
    *":$RUST_PORTABLE_HOME/bin:"*) ;;
    *) PATH="$RUST_PORTABLE_HOME/bin${PATH:+:$PATH}" ;;
esac
export PATH

unset _rust_portable_self
unset _rust_portable_dir
