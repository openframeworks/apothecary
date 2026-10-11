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
# Exercise the real launcher boundary: cmd.exe receives only a batch pathname,
# while quotes and Windows command syntax remain in the generated file.
source "$ROOT/apothecary/formulas/angle/angle.sh"
cmd.exe() {
    [ "$#" -eq 4 ] && [ "$1" = '//d' ] && [ "$2" = '//c' ] && [ "$3" = call ]
    [ -f "$4" ]
    cp "$4" "$fixture/launched.cmd"
    printf '%s\n' "$4" > "$fixture/launched-path"
    return "${ANGLE_TEST_EXIT:-0}"
}
_angle_win_run 'call "C:\path with spaces\bootstrap\win_tools.bat"'
tr -d '\r' < "$fixture/launched.cmd" > "$fixture/launched.txt"
grep -Fx 'call "C:\path with spaces\bootstrap\win_tools.bat"' "$fixture/launched.txt"
grep -E '^set "PATH=.*;%PATH%"$' "$fixture/launched.txt"
[ ! -e "$(cat "$fixture/launched-path")" ]
ANGLE_TEST_EXIT=17
if _angle_win_run 'call gclient.bat sync'; then
    echo 'Windows launcher swallowed command failure' >&2
    exit 1
else
    [ "$?" -eq 17 ]
fi
[ ! -e "$(cat "$fixture/launched-path")" ]
echo 'Windows batch transport, cleanup and exit propagation passed'
