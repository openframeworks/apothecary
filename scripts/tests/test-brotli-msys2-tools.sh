#!/usr/bin/env bash
# A leading /usr/bin must not mix MSYS CMake with native MinGW Ninja.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/brotli.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/usr/bin" "$fixture/out"
cat > "$fixture/usr/bin/cmake" <<'EOF'
#!/usr/bin/env bash
echo 'Wrong MSYS CMake selected' >&2
exit 99
EOF
chmod +x "$fixture/usr/bin/cmake"
export TYPE=msys2 FORCE_DOWNLOAD=1 USE_SAVE=0 C_STANDARD=17 PARALLEL_MAKE=2
export LIBS_DIR="$fixture/out" PATH="$fixture/usr/bin:$PATH"
export BROTLI_TOOL_LOG="$fixture/invocations"
unset CC
echoInfo() { :; }
for ARCH in mingw64 ucrt64 clang64 clangarm64; do
    export ARCH MINGW_PREFIX="$fixture/$ARCH native"
    mkdir -p "$MINGW_PREFIX/bin"
    cat > "$MINGW_PREFIX/bin/cmake.exe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$0" "$@" >> "$BROTLI_TOOL_LOG"
EOF
    for tool in cmake ninja pkgconf gcc clang; do
        if [ "$tool" != cmake ]; then printf '#!/usr/bin/env bash\nexit 0\n' > "$MINGW_PREFIX/bin/$tool.exe"; fi
        chmod +x "$MINGW_PREFIX/bin/$tool.exe"
    done
    : > "$BROTLI_TOOL_LOG"
    build brotli
    [ "$(grep -Fxc "$MINGW_PREFIX/bin/cmake.exe" "$BROTLI_TOOL_LOG")" -eq 3 ]
    grep -Fxq -- "-DCMAKE_MAKE_PROGRAM=$MINGW_PREFIX/bin/ninja.exe" "$BROTLI_TOOL_LOG"
    case "$ARCH" in clang*) compiler=clang ;; *) compiler=gcc ;; esac
    grep -Fxq -- "-DCMAKE_C_COMPILER=$MINGW_PREFIX/bin/$compiler.exe" "$BROTLI_TOOL_LOG"
    [ "$(_brotli_msys2_tool pkgconf)" = "$MINGW_PREFIX/bin/pkgconf.exe" ]
done
MINGW_PREFIX="$fixture/missing"
if build brotli >/dev/null 2>&1; then
    echo 'Missing native CMake must fail instead of falling back to MSYS CMake' >&2
    exit 1
fi
echo 'All four Brotli MSYS2 flavors select matching native CMake, Ninja, compiler and pkg-config'
