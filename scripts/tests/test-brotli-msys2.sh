#!/usr/bin/env bash
# Exercise the real ZIP packager and link/run a consumer of the extracted output.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/brotli.sh"
: "${ARCH:?ARCH must identify the MSYS2 flavor}"
cpu=$(_brotli_msys2_cpu)
output=$(cd "${1:-$ROOT/out}" && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export TYPE=msys2 TARGET=msys2
OUTPUT_FOLDER="$output" ALWAYS_BUILD=1 PACKAGE_LIBS=brotli \
    bash "$ROOT/scripts/package-individual.sh" msys2
mkdir -p "$fixture/extracted"
archive="$output/oF_brotli_msys2_${ARCH}.zip"
(cd "$fixture/extracted" && cmake -E tar xf "$archive")
dest="$fixture/extracted/brotli"
libdir="$dest/lib/msys2/$cpu"
for component in brotlicommon brotlidec brotlienc; do
    test -s "$libdir/lib$component.a"
    test -s "$libdir/lib$component.pc"
done
test -s "$dest/include/brotli/decode.h"
test -s "$dest/license/LICENSE"
grep -Fxq "version = \"$VER\"" "$libdir/brotli.pkl"
grep -Fxq "buildNumber = \"$BUILD_ID\"" "$libdir/brotli.pkl"
if command -v sha256sum >/dev/null 2>&1; then
    digest=$(sha256sum "$libdir/libbrotlidec.a" | cut -d ' ' -f 1)
else
    digest=$(shasum -a 256 "$libdir/libbrotlidec.a" | cut -d ' ' -f 1)
fi
grep -Fxq "binarySha = \"$digest\"" "$libdir/brotli.pkl"
printf '%s\n' libbrotlienc.a libbrotlidec.a libbrotlicommon.a > "$fixture/expected-order"
cmp "$fixture/expected-order" "$libdir/libsorder.make"
export PKG_CONFIG_LIBDIR="$libdir" PKG_CONFIG_PATH=""
test "$(pkg-config --modversion brotli)" = "$VER"
cp "$ROOT/scripts/tests/test-brotli-msys2.c" "$fixture/consumer.c"
cat > "$fixture/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(brotli_package_consumer C)
find_package(PkgConfig REQUIRED)
pkg_check_modules(BROTLI REQUIRED brotli)
add_executable(consumer consumer.c)
target_include_directories(consumer PRIVATE ${BROTLI_STATIC_INCLUDE_DIRS})
target_link_directories(consumer PRIVATE ${BROTLI_STATIC_LIBRARY_DIRS})
target_link_libraries(consumer PRIVATE ${BROTLI_STATIC_LIBRARIES})
EOF
case "$ARCH" in
    clang64|clangarm64) compiler="${CC:-clang}" ;;
    *) compiler="${CC:-gcc}" ;;
esac
cmake -S "$fixture" -B "$fixture/build" -G Ninja -DCMAKE_C_COMPILER="$compiler"
cmake --build "$fixture/build"
if [ "${BROTLI_TEST_COMPILE_ONLY:-0}" != 1 ]; then
    "$fixture/build/consumer.exe"
fi
echo "Brotli $ARCH: extracted ZIP, metadata, pkg-config and consumer link passed"
