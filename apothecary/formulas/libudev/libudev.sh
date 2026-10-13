#!/usr/bin/env bash
# Linux modular libudev: preserves the upstream libudev pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=3.2.15
BUILD_ID=1
SHA256=eb69809fc0d1187f2463ab2149c53aa9f42a78e59f14ebea68eae6cb6b4fc1c3
DEFINES="--disable-static --enable-shared --disable-programs --disable-manpages --disable-blkid --disable-kmod --disable-selinux"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://github.com/eudev-project/eudev/releases/download/v3.2.15/eudev-3.2.15.tar.gz"
    verify_sha256 "eudev-3.2.15.tar.gz" "$SHA256"
    tar -xf "eudev-3.2.15.tar.gz"
    mv "eudev-3.2.15" libudev
    rm -f "eudev-3.2.15.tar.gz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    mkdir -p "$bdir"
    cd "$bdir"
    ../configure --prefix="$prefix" --libdir="$prefix/lib" --disable-static --enable-shared --disable-programs --disable-manpages --disable-blkid --disable-kmod --disable-selinux --with-rootlibdir="$prefix/lib"
    make -j "${PARALLEL_MAKE:-2}"
    make install
    cd ..
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -R "$prefix/include/." "$1/include/"
    cp -R "$prefix/lib/." "$1/lib/$TYPE/$PLATFORM/"
    if [ -d "$prefix/share" ]; then
        mkdir -p "$1/share"
        cp -R "$prefix/share/." "$1/share/"
    fi
    if [ -d "$prefix/etc" ]; then
        mkdir -p "$1/etc"
        cp -R "$prefix/etc/." "$1/etc/"
    fi
    cp "$FORMULA_DIR/README.md" "$1/README.md"
    local license
    for license in COPYING LICENSE LICENSE.txt COPYING.LIB; do
        if [ -f "$license" ]; then cp "$license" "$1/license/"; fi
    done
    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/libudev.so" "libudev.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "libudev" "$ARCH" "$VER" "$LIBS_DIR_REAL/libudev/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
