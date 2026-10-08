#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT
export BREW_TEST_LOG="$SCRATCH/calls"
cat > "$SCRATCH/brew" <<'BREW'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$BREW_TEST_LOG"
case "$1" in
    list) [[ "$4" != missing ]] ;;
    install)
        if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
            [[ "${HOMEBREW_NO_AUTO_UPDATE:-}" == 1 ]]
            [[ "${HOMEBREW_NO_INSTALL_UPGRADE:-}" == 1 ]]
            [[ "${HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK:-}" == 1 ]]
        fi
        [[ "${BREW_TEST_FAIL:-0}" != 1 ]] ;;
    update) : ;;
    *) exit 1 ;;
esac
BREW
chmod +x "$SCRATCH/brew"
export PATH="$SCRATCH:$PATH"
GITHUB_ACTIONS=true bash "$ROOT/scripts/apple-install-tools.sh" cmake missing ccache gtk-doc wget2
printf 'list --formula --versions cmake\nlist --formula --versions missing\ninstall --formula missing\n' > "$SCRATCH/expected"
cmp "$SCRATCH/expected" "$BREW_TEST_LOG"
: > "$BREW_TEST_LOG"
GITHUB_ACTIONS=true bash "$ROOT/scripts/apple-install-tools.sh" cmake ccache
printf 'list --formula --versions cmake\n' > "$SCRATCH/expected"
cmp "$SCRATCH/expected" "$BREW_TEST_LOG"
: > "$BREW_TEST_LOG"
GITHUB_ACTIONS=false bash "$ROOT/scripts/apple-install-tools.sh" cmake ccache
printf 'update\ninstall --formula cmake ccache\n' > "$SCRATCH/expected"
cmp "$SCRATCH/expected" "$BREW_TEST_LOG"
if GITHUB_ACTIONS=true BREW_TEST_FAIL=1 bash "$ROOT/scripts/apple-install-tools.sh" missing; then
    echo 'FAIL: Homebrew install failure ignored' >&2; exit 1
fi
echo 'Apple setup reuse, missing-tool installation, local behavior and failure propagation passed'
