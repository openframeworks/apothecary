#!/usr/bin/env bash
# Linux modular glvnd: preserves the upstream gl pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=1.7.0
BUILD_ID=1
SHA256=2b6e15b06aafb4c0b6e2348124808cbd9b291c647299eaaba2e3202f51ff2f3d
DEFINES="-Dx11=enabled -Dglx=enabled -Degl=true -Dgles1=true -Dgles2=true"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://gitlab.freedesktop.org/glvnd/libglvnd/-/archive/v1.7.0/libglvnd-v1.7.0.tar.gz"
    verify_sha256 "libglvnd-v1.7.0.tar.gz" "$SHA256"
    tar -xf "libglvnd-v1.7.0.tar.gz"
    mv "libglvnd-v1.7.0" glvnd
    rm -f "libglvnd-v1.7.0.tar.gz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Dx11=enabled -Dglx=enabled -Degl=true -Dgles1=true -Dgles2=true
    meson compile -C "$bdir" -j "${PARALLEL_MAKE:-2}"
    meson install -C "$bdir"
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
    cp "$FORMULA_DIR/LICENSE-NOTICES.txt" "$1/license/"
    local license
    for license in COPYING LICENSE LICENSE.txt COPYING.LIB; do
        if [ -f "$license" ]; then cp "$license" "$1/license/"; fi
    done
    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/libGL.so" "glvnd.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "glvnd" "$ARCH" "$VER" "$LIBS_DIR_REAL/glvnd/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
