#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
LIBS_ROOT=${OUTPUT_FOLDER:-"$ROOT/out"}
if [ "${ARCH:-32}" == "64" ]; then
    platform=WASM64
else
    platform=WASM
fi
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# Other Apothecary dependencies use pthread-enabled Emscripten objects.
"$EMSDK/upstream/emscripten/emcc" \
    "$ROOT/apothecary/formulas/cairo/emscripten-smoke.c" \
    -I"$LIBS_ROOT/cairo/include/cairo" \
    "$LIBS_ROOT/cairo/lib/emscripten/$platform/libcairo.a" \
    "$LIBS_ROOT/pixman/lib/emscripten/$platform/libpixman-1.a" \
    "$LIBS_ROOT/freetype/lib/emscripten/$platform/libfreetype.a" \
    "$LIBS_ROOT/libpng/lib/emscripten/$platform/libpng16.a" \
    "$LIBS_ROOT/zlib/lib/emscripten/$platform/zlib.a" \
    "$LIBS_ROOT/brotli/lib/emscripten/$platform/libbrotlidec.a" \
    "$LIBS_ROOT/brotli/lib/emscripten/$platform/libbrotlicommon.a" \
    -pthread -matomics -mbulk-memory -sENVIRONMENT=node \
    -o "$test_dir/cairo-smoke.js"
node "$test_dir/cairo-smoke.js"
