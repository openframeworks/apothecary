#!/usr/bin/env bash
# Linux modular glu: preserves the upstream glu pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=9.0.3
BUILD_ID=1
SHA256=bd43fe12f374b1192eb15fe20e45ff456b9bc26ab57f0eee919f96ca0f8a330f
DEFINES="-Dgl_provider=glvnd"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://archive.mesa3d.org/glu/glu-9.0.3.tar.xz"
    verify_sha256 "glu-9.0.3.tar.xz" "$SHA256"
    tar -xf "glu-9.0.3.tar.xz"
    mv "glu-9.0.3" glu
    rm -f "glu-9.0.3.tar.xz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Dgl_provider=glvnd
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
    secure "$1/lib/$TYPE/$PLATFORM/libGLU.so" "glu.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "glu" "$ARCH" "$VER" "$LIBS_DIR_REAL/glu/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
