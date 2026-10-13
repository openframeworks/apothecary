#!/usr/bin/env bash
# Linux modular mpg123: preserves the upstream libmpg123 pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=1.33.7
BUILD_ID=1
SHA256=31d0e35a4ca567ec9b5ebda6c3062bb4435d6d3eacd6ef0d95cadd7854dc03ee
DEFINES="--disable-static --enable-shared --disable-components --enable-libmpg123"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://www.mpg123.de/download/mpg123-1.33.7.tar.bz2"
    verify_sha256 "mpg123-1.33.7.tar.bz2" "$SHA256"
    tar -xf "mpg123-1.33.7.tar.bz2"
    mv "mpg123-1.33.7" mpg123
    rm -f "mpg123-1.33.7.tar.bz2"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    mkdir -p "$bdir"
    cd "$bdir"
    ../configure --prefix="$prefix" --libdir="$prefix/lib" --disable-static --enable-shared --disable-components --enable-libmpg123
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
    secure "$1/lib/$TYPE/$PLATFORM/libmpg123.so" "mpg123.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "mpg123" "$ARCH" "$VER" "$LIBS_DIR_REAL/mpg123/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
