#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/scripts/package-platform.sh"
for library in glew glfw libusb openssl portaudio videoInput rtAudio curl metalangle pkg-config automake; do
    if formula_has_package_for_target "$library" emscripten "$ROOT/apothecary"; then
        echo "Unexpected Emscripten package: $library" >&2; exit 1
    fi
done
for library in zlib assimp FreeImage json glm utf8 cairo opencv; do
    formula_has_package_for_target "$library" emscripten "$ROOT/apothecary"
done
formula_has_package_for_target videoInput vs "$ROOT/apothecary"
formula_has_package_for_target glfw osx "$ROOT/apothecary"
TEMP=$(mktemp -d)
trap 'rm -rf "$TEMP"' EXIT
mkdir -p "$TEMP/out/zlib" "$TEMP/out/json/include" "$TEMP/bin"
printf fixture > "$TEMP/out/zlib/fixture.a"
printf headers > "$TEMP/out/json/include/json.hpp"
export TARGET=emscripten ARCH=32 ALWAYS_BUILD=1 OUTPUT_FOLDER="$TEMP/out"
PACKAGE_LIBS='pkg-config automake glew glfw libusb openssl portaudio videoInput rtAudio curl metalangle zlib json' \
    bash "$ROOT/scripts/package-individual.sh" > "$TEMP/explicit.log"
test -s "$TEMP/out/oF_zlib_emscripten_32.tar.bz2"
test -s "$TEMP/out/oF_json_emscripten_32.tar.bz2"
FORMULAS_OVERRIDE='pkg-config glew zlib' bash "$ROOT/scripts/package-individual.sh" > "$TEMP/implicit.log"
if PACKAGE_LIBS=missing-library bash "$ROOT/scripts/package-individual.sh" > "$TEMP/missing.log" 2>&1; then
    echo 'Missing real library must still fail' >&2; exit 1
fi
# Model the Windows archiver on a case-sensitive filesystem. Publication and
# metadata recording must see exactly the same lowercase filename.
cat > "$TEMP/bin/C:\Program Files\7-Zip\7z.exe" <<'ARCHIVER'
#!/usr/bin/env bash
printf fixture-archive > "$2"
ARCHIVER
chmod +x "$TEMP/bin/C:\Program Files\7-Zip\7z.exe"
PATH="$TEMP/bin:$PATH" TARGET=msys2 ARCH=clang64 MSYSTEM=CLANG64 RELEASE=latest \
    FORMULAS_OVERRIDE=zlib bash "$ROOT/scripts/package.sh" > "$TEMP/msys2.log"
test -s "$TEMP/out/openFrameworksLibs_latest_msys2_clang64.zip"
if ls "$TEMP/out" | grep -Fxq openFrameworksLibs_latest_msys2_CLANG64.zip; then
    echo 'Archive filename must use lowercase MSYS2 flavor' >&2; exit 1
fi
echo 'Platform packaging: unsupported targets/tools skipped; valid and header-only outputs kept; missing libraries fail; MSYS2 names match publication'
