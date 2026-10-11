#!/usr/bin/env bash
# Exercise first-run setup ordering with a checkout that has no generated tools.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/angle/angle.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.vendor/depot_tools/.git" "$fixture/scripts"
cd "$fixture"
export ANGLE_TEST_LOG="$fixture/commands"
verify_git_commit() { [ "$1" = "$fixture/.vendor/depot_tools" ]; [ "$2" = "$DEPOT_TOOLS_COMMIT" ]; }
printf 'printf "bootstrap\\n" >> "$ANGLE_TEST_LOG"\ntouch "$(dirname "$0")/python3_bin_reldir.txt"\n' > .vendor/depot_tools/ensure_bootstrap
python3() { [ -f .vendor/depot_tools/python3_bin_reldir.txt ]; printf 'config\n' >> "$ANGLE_TEST_LOG"; }
gclient() { [ -f .vendor/depot_tools/python3_bin_reldir.txt ]; printf 'sync\n' >> "$ANGLE_TEST_LOG"; }
TYPE=osx prepare
printf 'bootstrap\nconfig\nsync\n' > expected
cmp expected "$ANGLE_TEST_LOG"
# Windows must bootstrap before gclient, then run GN/Ninja through cmd.exe.
: > "$ANGLE_TEST_LOG"
_angle_git_win_dir() { echo '/c/Program Files/Git/cmd'; }
cygpath() { printf '%s\n' "$2"; }
_angle_win_run() { printf '%s\n' "$*" >> "$ANGLE_TEST_LOG"; }
TYPE=vs prepare
head -1 "$ANGLE_TEST_LOG" | grep -F 'bootstrap/win_tools.bat'
sed -n '2p' "$ANGLE_TEST_LOG" | grep -F 'python scripts\bootstrap.py'
sed -n '3p' "$ANGLE_TEST_LOG" | grep -F 'gclient sync --no-history --shallow'
gn() { echo "Unexpected direct GN invocation" >&2; return 1; }
autoninja() { echo "Unexpected direct Ninja invocation" >&2; return 1; }
setup_vs_vars() { VS_INSTALL_PATH='C:\Program Files\Microsoft Visual Studio'; }
TYPE=vs ARCH=64 PLATFORM=x64 build
grep -F 'call gn.bat gen out/Release_x64' "$ANGLE_TEST_LOG" | grep -F 'target_os=\"win\"'
grep -F 'call autoninja.bat -C out/Release_x64 libEGL libGLESv2' "$ANGLE_TEST_LOG"
echo 'ANGLE bootstrap ordering and Windows command tests passed'
