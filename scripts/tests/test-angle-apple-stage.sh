#!/usr/bin/env bash
# Native smoke check for ANGLE's dynamic XCFramework staging (no ANGLE build).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/out/angle/include" "$fixture/out/angle/license"
printf 'int stage_test(void) { return 1; }\n' > "$fixture/test.c"
printf 'int stage_test(void);\n' > "$fixture/out/angle/include/test.h"
printf 'fixture\n' > "$fixture/out/angle/license/LICENSE"
metadata() {
    printf 'version = "fixture"\nbinary = "old"\nbinarySha = "old"\narchitecture = "old"\n' > "$1/angle.pkl"
}
for arch in x86_64 arm64; do
    platform=MAC
    [ "$arch" != arm64 ] || platform=MAC_ARM64
    dir="$fixture/out/angle/bin/osx/$platform"
    mkdir -p "$dir"
    for name in libEGL libGLESv2; do
        xcrun clang -arch "$arch" -mmacosx-version-min=12.0 -dynamiclib "$fixture/test.c" -o "$dir/$name.dylib"
    done
    metadata "$dir"
done
OUTPUT_FOLDER="$fixture/out" ANGLE_STAGE_DIR="$fixture/staged" TYPE=osx bash "$ROOT/apothecary/formulas/angle/stage-apple.sh"
for name in libEGL libGLESv2; do
    binary=$(find "$fixture/staged/lib/macos/$name.xcframework" -name "$name.dylib" -type f)
    [ -n "$binary" ]
    xcrun lipo "$binary" -verify_arch arm64
    xcrun lipo "$binary" -verify_arch x86_64
    grep -F "binarySha = \"$(shasum -a 256 "$binary" | cut -d ' ' -f 1)\"" "$(dirname "$binary")/angle.pkl"
done
for platform in OS64 SIMULATOR64 SIMULATORARM64; do
    case "$platform" in
        OS64) target=arm64-apple-ios15.0; sdk=iphoneos ;;
        SIMULATOR64) target=x86_64-apple-ios15.0-simulator; sdk=iphonesimulator ;;
        SIMULATORARM64) target=arm64-apple-ios15.0-simulator; sdk=iphonesimulator ;;
    esac
    for name in libEGL libGLESv2; do
        dir="$fixture/out/angle/lib/ios/$platform/$name.framework"
        mkdir -p "$dir/Headers"
        cp "$fixture/out/angle/include/test.h" "$dir/Headers/"
        xcrun --sdk "$sdk" clang -target "$target" -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" \
            -dynamiclib "$fixture/test.c" -install_name "@rpath/$name.framework/$name" -o "$dir/$name"
        cat > "$dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>org.openframeworks.fixture.$name</string>
<key>CFBundlePackageType</key><string>FMWK</string>
</dict></plist>
PLIST
        metadata "$dir"
    done
done
OUTPUT_FOLDER="$fixture/out" ANGLE_STAGE_DIR="$fixture/staged" TYPE=ios bash "$ROOT/apothecary/formulas/angle/stage-apple.sh"
for name in libEGL libGLESv2; do
    xc="$fixture/staged/lib/ios/$name.xcframework"
    [ -f "$xc/ios-arm64/$name.framework/$name" ]
    binary="$xc/ios-arm64_x86_64-simulator/$name.framework/$name"
    xcrun lipo "$binary" -verify_arch arm64
    xcrun lipo "$binary" -verify_arch x86_64
    grep -F "binarySha = \"$(shasum -a 256 "$binary" | cut -d ' ' -f 1)\"" "$(dirname "$binary")/angle.pkl"
done
echo 'ANGLE dynamic macOS and iOS XCFramework staging passed'
