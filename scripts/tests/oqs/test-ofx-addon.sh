#!/usr/bin/env bash
# Native tests of a generated ofxOQS addon. Optional OF_ROOT copies it into addons/.
set -euo pipefail
ADDON=${1:?Usage: test-ofx-addon.sh ADDON_DIR [OF_ROOT]}
OF_ROOT=${2:-}
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ADDON="$(cd "$ADDON" && pwd -P)"

test -f "$ADDON/addon_config.mk"
test -f "$ADDON/src/ofxOQS.cpp"
grep -q 'ADDON_NAME = ofxOQS' "$ADDON/addon_config.mk"

host=$(uname -m)
case "$(uname -s)" in
    Darwin)
        lib="$ADDON/libs/liboqs/lib/osx/liboqs.a"
        test -f "$lib"
        lipo -info "$lib" | grep -E 'x86_64|arm64'
        clang -std=c11 -I"$ADDON/libs/liboqs/include" \
            "$ROOT/scripts/tests/oqs/liboqs.c" "$lib" \
            -o "$ADDON/.liboqs-smoke"
        "$ADDON/.liboqs-smoke"
        rm -f "$ADDON/.liboqs-smoke"
        case "$host" in
            arm64|aarch64) platform=MAC_ARM64 ;;
            x86_64) platform=MAC ;;
            *) echo "Unsupported host $host" >&2; exit 1 ;;
        esac
        bash "$ROOT/scripts/tests/oqs/test-openssh.sh" "$ADDON/libs" osx "$platform"
        test -x "$ADDON/bin/osx/ssh"
        "$ADDON/bin/osx/ssh" -V
        ;;
    Linux)
        lib=
        for candidate in \
            "$ADDON/libs/liboqs/lib/linux64/liboqs.a" \
            "$ADDON/libs/liboqs/lib/linux/64/liboqs.a" \
            "$ADDON/libs/liboqs/lib/linuxarm64/liboqs.a" \
            "$ADDON/libs/liboqs/lib/linux/arm64/liboqs.a" \
            "$ADDON/libs/liboqs/lib/linuxaarch64/liboqs.a" \
            "$ADDON/libs/liboqs/lib/linux/aarch64/liboqs.a"
        do
            [ -f "$candidate" ] || continue
            lib=$candidate
            break
        done
        [ -n "$lib" ]
        cc -std=c11 -I"$ADDON/libs/liboqs/include" \
            "$ROOT/scripts/tests/oqs/liboqs.c" "$lib" -lpthread \
            -o "$ADDON/.liboqs-smoke"
        "$ADDON/.liboqs-smoke"
        rm -f "$ADDON/.liboqs-smoke"
        ;;
    *)
        echo "Unsupported host for ofxOQS tests: $(uname -s)" >&2
        exit 1
        ;;
esac

if [ -n "$OF_ROOT" ]; then
    OF_ROOT="$(cd "$OF_ROOT" && pwd -P)"
    mkdir -p "$OF_ROOT/addons"
    rm -rf "$OF_ROOT/addons/ofxOQS"
    cp -R "$ADDON" "$OF_ROOT/addons/ofxOQS"
    test -f "$OF_ROOT/addons/ofxOQS/example/addons.make"
    grep -q ofxOQS "$OF_ROOT/addons/ofxOQS/example/addons.make"
    printf 'Installed private ofxOQS into %s/addons/ofxOQS\n' "$OF_ROOT"
fi
echo 'ofxOQS private addon layout and native smoke tests passed'
