#!/usr/bin/env bash
# Linux modular alsa: preserves the upstream alsa pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=1.2.16.1
BUILD_ID=1
SHA256=f740db7f488255944ffd4428416ee3390a96742856916433df468c281436480e
DEFINES="--disable-static --enable-shared --disable-python"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://www.alsa-project.org/files/pub/lib/alsa-lib-1.2.16.1.tar.bz2"
    verify_sha256 "alsa-lib-1.2.16.1.tar.bz2" "$SHA256"
    tar -xf "alsa-lib-1.2.16.1.tar.bz2"
    mv "alsa-lib-1.2.16.1" alsa
    rm -f "alsa-lib-1.2.16.1.tar.bz2"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    mkdir -p "$bdir"
    cd "$bdir"
    ../configure --prefix="$prefix" --libdir="$prefix/lib" --disable-static --enable-shared --disable-python
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
    secure "$1/lib/$TYPE/$PLATFORM/libasound.so" "alsa.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "alsa" "$ARCH" "$VER" "$LIBS_DIR_REAL/alsa/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
