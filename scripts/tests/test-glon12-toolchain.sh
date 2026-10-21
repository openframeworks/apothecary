#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
source "$ROOT/apothecary/formulas/glon12.sh"
cd "$fixture"
msvc_root="$fixture/VS tools/VC/Tools/MSVC/fixture"
VS_BIN_PATH="$msvc_root/bin/Hostx64/arm64"
GLON12_WINDOWS_SDK_ROOT="$fixture/sdk"
mkdir -p "$VS_BIN_PATH" "$msvc_root/lib/arm64" "$GLON12_WINDOWS_SDK_ROOT/Lib/10.0.26100.0"
touch "$VS_BIN_PATH/cl.exe" "$msvc_root/lib/arm64/msvcrt.lib"
setup_vs_vars() { VS_INSTALL_PATH="$fixture/VS tools"; }
echoWarning() { echo "$*" >&2; }
echoError() { echo "$*" >&2; }
cygpath() { printf '%s\n' "$2"; }
python() { echo x86_64; }
meson() { printf '%s\n' "$*" >> "$fixture/meson-commands"; }
TYPE=vs ARCH=arm64ec PLATFORM=ARM64EC PARALLEL_MAKE=2
# Missing Hostx64/arm64ec must reach the supported arm64 compiler fallback
# under errexit, instead of exiting during the optional directory probe.
build > /dev/null
[[ "$CC" == "$msvc_root/bin/Hostx64/arm64/cl.exe" ]]
[[ "$_CL_" == *'/arm64EC'* ]]
[[ "$LIB" == *'/lib/arm64'* ]]
[[ "$LIB" == *'/ucrt/arm64'* ]]
[[ "$LIB" == *'/um/arm64'* ]]
[[ "$LIB" != *'/arm64ec'* ]]
grep -F "cpu = 'arm64ec'" meson-cpu-ARM64EC.ini
grep -F -- '--backend=vs' "$fixture/meson-commands"
grep -F "c_link_args = ['/machine:arm64ec']" meson-cpu-ARM64EC.ini
grep -F "cpp_link_args = ['/machine:arm64ec']" meson-cpu-ARM64EC.ini
grep -F -- '--cross-file meson-cpu-ARM64EC.ini' "$fixture/meson-commands"
[ "$(wc -l < "$fixture/meson-commands" | tr -d ' ')" = 3 ]
# Prefer the dedicated compiler when that optional toolset is installed.
mkdir -p "$msvc_root/bin/Hostx64/arm64ec"
touch "$msvc_root/bin/Hostx64/arm64ec/cl.exe"
build > /dev/null
[[ "$CC" == "$msvc_root/bin/Hostx64/arm64ec/cl.exe" ]]
[[ "$LIB" == *'/lib/arm64'* ]]
[[ "$LIB" != *'/arm64ec'* ]]
echo 'GLon12 ARM64EC optional-toolset fallback and dedicated-toolset selection passed'
