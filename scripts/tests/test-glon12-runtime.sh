#!/usr/bin/env bash
# Exercise the real copy function against distinct SDK versions/architectures.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/glon12.sh"
echoInfo() { printf '%s\n' "$*"; }
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cd "$fixture"
export GLON12_WINDOWS_SDK_ROOT="$fixture/Windows SDK"
export SECURE_SCRIPT="$ROOT/scripts/secure.sh" TYPE=vs
export C_STANDARD=17 CPP_STANDARD=23 VERSION="$VER"
unset WindowsSDKVersion WINDOWSSDKVERSION GLON12_WINDOWS_SDK_VERSION
for sdk_version in 10.0.26100.0 10.0.28000.0; do
    mkdir -p "$GLON12_WINDOWS_SDK_ROOT/Lib/$sdk_version"
    for runtime_arch in x86 x64 arm64; do
        mkdir -p "$GLON12_WINDOWS_SDK_ROOT/bin/$sdk_version/$runtime_arch"
        printf '%s %s\n' "$sdk_version" "$runtime_arch" > "$GLON12_WINDOWS_SDK_ROOT/bin/$sdk_version/$runtime_arch/dxil.dll"
    done
done
[ "$(_glon12_sdk_version "$GLON12_WINDOWS_SDK_ROOT")" = 10.0.28000.0 ]
WindowsSDKVersion='10.0.26100.0\'
[ "$(_glon12_sdk_version "$GLON12_WINDOWS_SDK_ROOT")" = 10.0.26100.0 ]
export GLON12_WINDOWS_SDK_VERSION=10.0.28000.0
[ "$(_glon12_sdk_version "$GLON12_WINDOWS_SDK_ROOT")" = 10.0.28000.0 ]
export GLON12_WINDOWS_SDK_VERSION=10.0.26100.0
printf 'fixture license\n' > LICENSE
for ARCH in 32 64 arm64 arm64ec; do
    export ARCH
    case "$ARCH" in
        32) PLATFORM=Win32; runtime_arch=x86 ;;
        64) PLATFORM=x64; runtime_arch=x64 ;;
        arm64) PLATFORM=ARM64; runtime_arch=arm64 ;;
        arm64ec) PLATFORM=ARM64EC; runtime_arch=x64 ;;
    esac
    export PLATFORM
    mkdir -p "build_vs_$PLATFORM/Release/bin"
    for dll in opengl32.dll libgallium_wgl.dll; do
        printf '%s %s\n' "$ARCH" "$dll" > "build_vs_$PLATFORM/Release/bin/$dll"
    done
    copy "$fixture/out/$ARCH/glon12" > "$fixture/copy-$ARCH.log" || exit 1
    set -e
    dest="$fixture/out/$ARCH/glon12/bin/vs/$PLATFORM"
    cmp "$GLON12_WINDOWS_SDK_ROOT/bin/$GLON12_WINDOWS_SDK_VERSION/$runtime_arch/dxil.dll" "$dest/dxil.dll"
    grep -Fxq 'windowsSdkVersion = "10.0.26100.0"' "$dest/glon12.pkl"
    grep -Fxq "dxilSdkArchitecture = \"$runtime_arch\"" "$dest/glon12.pkl"
    grep -Fxq "dxilBinarySha = \"$(calculate_hash "$dest/dxil.dll")\"" "$dest/glon12.pkl"
done
# A matching build number cannot make an incomplete runtime usable.
export ARCH=64 PLATFORM=x64 LIBS_DIR_REAL="$fixture/out/64" LOAD_SCRIPT="$ROOT/scripts/load.sh"
[ "$(load glon12 | tail -1)" = 1 ]
mv "$fixture/out/64/glon12/bin/vs/x64/dxil.dll" "$fixture/cached-validator"
[ "$(load glon12 | tail -1)" = 0 ]
# Explicit SDK versions must never silently use another version's validator.
export GLON12_WINDOWS_SDK_VERSION=10.0.28000.0 ARCH=64 PLATFORM=x64
mv "$GLON12_WINDOWS_SDK_ROOT/bin/10.0.28000.0/x64/dxil.dll" "$fixture/validator-saved"
if copy "$fixture/missing-runtime/glon12" > "$fixture/missing.log" 2>&1; then
    echo 'GLon12 copy accepted a missing selected-SDK validator' >&2; exit 1
fi
set -e
grep -Fq 'required DXIL shader validator missing' "$fixture/missing.log"
test ! -f "$fixture/missing-runtime/glon12/bin/vs/x64/glon12.pkl"
# Run the actual individual packager; CMake supplies ZIP transport for this
# portable fixture, while the native Windows workflow uses 7-Zip.
mkdir -p "$fixture/bin" "$fixture/extracted"
cat > "$fixture/bin/C:\Program Files\7-Zip\7z.exe" <<'EOF'
#!/usr/bin/env bash
exec cmake -E tar cf "$2" --format=zip "$3"
EOF
chmod +x "$fixture/bin/C:\Program Files\7-Zip\7z.exe"
PATH="$fixture/bin:$PATH" OUTPUT_FOLDER="$fixture/out/arm64ec" ARCH=arm64ec \
    ALWAYS_BUILD=1 PACKAGE_LIBS=glon12 bash "$ROOT/scripts/package-individual.sh" vs > "$fixture/package.log"
(cd "$fixture/extracted" && cmake -E tar xf "$fixture/out/arm64ec/oF_glon12_vs_arm64ec.zip")
cmp "$fixture/out/arm64ec/glon12/bin/vs/ARM64EC/dxil.dll" "$fixture/extracted/glon12/bin/vs/ARM64EC/dxil.dll"
echo 'GLon12 runtime copy: selected SDK, all architectures, exact bytes, metadata and missing-validator rejection passed'
