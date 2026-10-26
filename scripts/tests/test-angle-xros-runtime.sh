#!/usr/bin/env bash
# Link the builtins needed by ANGLE at its actual visionOS deployment minimum.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/angle/angle.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/consumer.c" <<'EOF'
unsigned __int128 divide128(unsigned __int128 a, unsigned __int128 b) {
    return a / b;
}
double convert128(__int128 a) { return (double)a; }
EOF
for PLATFORM in VISIONOS SIMULATOR_VISIONOS; do
    TYPE=xros
    ARCH=arm64
    runtime_dir=$(_angle_xros_runtime_dir)
    case "$PLATFORM" in
        VISIONOS) sdk=xros; target=arm64-apple-xros2.0; libname=xros; binary_platform=VISIONOS ;;
        *) sdk=xrsimulator; target=arm64-apple-xros2.0-simulator; libname=xrossim; binary_platform=VISIONOSSIMULATOR ;;
    esac
    args=$(_angle_gn_args)
    [[ "$args" == *"angle_xros_clang_runtime_dir=\"$runtime_dir\""* ]]
    binary="$fixture/$PLATFORM.dylib"
    xcrun --sdk "$sdk" clang -target "$target" \
        -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
        -dynamiclib -Wl,-no_warn_duplicate_libraries -Wl,-fatal_warnings \
        "$fixture/consumer.c" "$runtime_dir/libclang_rt.$libname.a" -o "$binary"
    xcrun vtool -show-build "$binary" > "$fixture/build-version"
    grep -E "platform $binary_platform$" "$fixture/build-version"
    grep -E 'minos 2\.0$' "$fixture/build-version"
    nm -U "$binary" > "$fixture/symbols"
    grep -E ' [Tt] ___udivti3$' "$fixture/symbols"
    grep -E ' [Tt] ___floattidf$' "$fixture/symbols"
done
echo 'Xcode builtins link for visionOS device and simulator at minimum 2.0'
