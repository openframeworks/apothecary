#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/opencv/opencv.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/libs"
# Exercise the real build function's Apple configuration for devices/simulators.
cmake() {
    if [[ ${1:-} == .. ]]; then
        printf '%s\n' "$@" > "$fixture/args"
    fi
}
export LIBS_DIR="$fixture/libs" APOTHECARY_DIR="$ROOT/apothecary" C_STANDARD=11 CPP_STANDARD=23
export MIN_SDK_VER=15.0 FLAG_RELEASE=-O3 VERBOSE_MAKEFILE=OFF PARALLEL_MAKE=2
cd "$fixture"
for TYPE in osx ios tvos xros catos watchos; do
    for ARCH in arm64 SIM_arm64 x86_64; do
        export TYPE ARCH PLATFORM="$ARCH"
        build
        grep -Fx -- '-DWITH_KLEIDICV=OFF' "$fixture/args" >/dev/null
    done
done
unset -f cmake
if [[ $(uname -s) == Darwin ]]; then
    printf 'int clean_archive(void) { return 42; }\n' > clean.c
    printf 'extern int kleidicv_saturating_add_u8(void); int broken_archive(void) { return kleidicv_saturating_add_u8(); }\n' > broken.c
    xcrun clang -arch arm64 -c clean.c -o clean.o
    xcrun clang -arch arm64 -c broken.c -o broken.o
    xcrun ar rcs clean.a clean.o
    xcrun ar rcs broken.a broken.o
    _opencv_check_no_kleidicv clean.a
    if _opencv_check_no_kleidicv broken.a > "$fixture/rejected" 2>&1; then
        echo 'Unbundled KleidiCV dependency was incorrectly accepted' >&2
        exit 1
    fi
    grep -F 'unbundled KleidiCV dependency' "$fixture/rejected" >/dev/null
    nm() { return 7; }
    if _opencv_check_no_kleidicv clean.a; then
        echo 'nm inspection failure was incorrectly accepted' >&2
        exit 1
    fi
fi
printf 'Apple KleidiCV configuration checked; native symbol fixtures run on macOS\n'
