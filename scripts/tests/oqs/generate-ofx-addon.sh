#!/usr/bin/env bash
# Build a private ofxOQS addon from Apothecary OQS packages.
# Usage: generate-ofx-addon.sh PACKAGE_DIR DEST [TYPE]
set -euo pipefail

PACKAGE_DIR=${1:?Usage: generate-ofx-addon.sh PACKAGE_DIR DEST [TYPE]}
DEST=${2:?DEST is required}
TYPE=${3:-osx}
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
TEMPLATE="$ROOT/scripts/tests/oqs/ofxOQS"
PACKAGE_DIR="$(cd "$PACKAGE_DIR" && pwd -P)"

stage=$(mktemp -d "${TMPDIR:-/tmp}/ofxOQS-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT

extract_packages() {
    local archive
    shopt -s nullglob
    for archive in "$PACKAGE_DIR"/oF_liboqs_*.tar.bz2 "$PACKAGE_DIR"/oF_oqsprovider_*.tar.bz2 "$PACKAGE_DIR"/oF_openssh_*.tar.bz2; do
        tar -xjf "$archive" -C "$stage"
    done
    for name in liboqs oqsprovider openssh; do
        if [ -d "$PACKAGE_DIR/$name" ] && [ ! -d "$stage/$name" ]; then
            cp -R "$PACKAGE_DIR/$name" "$stage/$name"
        fi
        [ -d "$stage/$name" ] || { echo "Missing $name package in $PACKAGE_DIR" >&2; return 1; }
    done
}

copy_tree() {
    local src=$1 dest=$2
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
}

lipo_or_copy() {
    local dest=$1
    shift
    local -a inputs=()
    local src
    for src in "$@"; do
        [ -e "$src" ] || continue
        inputs+=("$src")
    done
    [ "${#inputs[@]}" -gt 0 ] || return 1
    mkdir -p "$(dirname "$dest")"
    if [ "${#inputs[@]}" -eq 1 ]; then
        cp "${inputs[0]}" "$dest"
        return 0
    fi
    if command -v lipo >/dev/null && lipo -create "${inputs[@]}" -output "$dest" 2>/dev/null; then
        return 0
    fi
    cp "${inputs[0]}" "$dest"
}

install_osx_libs() {
    local name=$1
    local dest_lib="$DEST/libs/$name/lib/osx"
    mkdir -p "$dest_lib"
    copy_tree "$stage/$name/include" "$DEST/libs/$name/include"
    [ -d "$stage/$name/license" ] && copy_tree "$stage/$name/license" "$DEST/libs/$name/license"
    case "$name" in
        liboqs)
            lipo_or_copy "$dest_lib/liboqs.a" \
                "$stage/liboqs/lib/osx/MAC_ARM64/liboqs.a" \
                "$stage/liboqs/lib/osx/MAC/liboqs.a"
            ;;
        oqsprovider)
            lipo_or_copy "$dest_lib/liboqsprovider.a" \
                "$stage/oqsprovider/lib/osx/MAC_ARM64/liboqsprovider.a" \
                "$stage/oqsprovider/lib/osx/MAC/liboqsprovider.a"
            mkdir -p "$dest_lib/ossl-modules"
            lipo_or_copy "$dest_lib/ossl-modules/oqsprovider.dylib" \
                "$stage/oqsprovider/lib/osx/MAC_ARM64/ossl-modules/oqsprovider.dylib" \
                "$stage/oqsprovider/lib/osx/MAC/ossl-modules/oqsprovider.dylib"
            ;;
    esac
    # Keep the original per-arch tree for OpenSSH helpers and cmake consumers.
    copy_tree "$stage/$name/lib" "$DEST/libs/$name/lib"
}

install_linux_libs() {
    local name=$1
    local arch
    copy_tree "$stage/$name/include" "$DEST/libs/$name/include"
    [ -d "$stage/$name/license" ] && copy_tree "$stage/$name/license" "$DEST/libs/$name/license"
    copy_tree "$stage/$name/lib" "$DEST/libs/$name/lib"
    for arch in 64 arm64 aarch64 armv6l armv7l; do
        [ -d "$stage/$name/lib/linux/$arch" ] || continue
        mkdir -p "$DEST/libs/$name/lib/linux$arch"
        cp -R "$stage/$name/lib/linux/$arch/." "$DEST/libs/$name/lib/linux$arch/"
    done
}

install_openssh() {
    copy_tree "$stage/openssh" "$DEST/libs/openssh"
    if [ "$TYPE" = osx ]; then
        mkdir -p "$DEST/bin/osx"
        local binary
        for binary in ssh sshd ssh-keygen scp sftp ssh-agent ssh-add ssh-keyscan; do
            lipo_or_copy "$DEST/bin/osx/$binary" \
                "$stage/openssh/bin/osx/MAC_ARM64/$binary" \
                "$stage/openssh/bin/osx/MAC/$binary" || true
            [ -f "$DEST/bin/osx/$binary" ] && chmod +x "$DEST/bin/osx/$binary"
        done
    fi
}

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$TEMPLATE/." "$DEST/"
extract_packages
case "$TYPE" in
    osx)
        install_osx_libs liboqs
        install_osx_libs oqsprovider
        ;;
    linux)
        install_linux_libs liboqs
        install_linux_libs oqsprovider
        ;;
    *)
        echo "Unsupported TYPE: $TYPE" >&2
        exit 1
        ;;
esac
install_openssh
printf 'Generated private ofxOQS addon at %s\n' "$DEST"
find "$DEST/libs" "$DEST/bin" -name 'liboqs.a' -o -name 'liboqsprovider.a' -o -name 'ssh' 2>/dev/null | sort
