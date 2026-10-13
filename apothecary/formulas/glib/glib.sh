#!/usr/bin/env bash
# Linux modular glib: preserves the upstream gio-2.0 pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=2.88.4
BUILD_ID=1
SHA256=25fd169f3b2f91fe2391ad297883ce0fcf30c69fc789ffd1c9672d1332b1c5a8
DEFINES="-Dtests=false -Dinstalled_tests=false -Dintrospection=disabled -Ddocumentation=false -Dman=false -Dgtk_doc=false"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://download.gnome.org/sources/glib/2.88/glib-2.88.4.tar.xz"
    verify_sha256 "glib-2.88.4.tar.xz" "$SHA256"
    tar -xf "glib-2.88.4.tar.xz"
    mv "glib-2.88.4" glib
    rm -f "glib-2.88.4.tar.xz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Dtests=false -Dinstalled_tests=false -Dintrospection=disabled -Ddocumentation=false -Dman=false -Dgtk_doc=false
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
    local license
    for license in COPYING LICENSE LICENSE.txt COPYING.LIB; do
        if [ -f "$license" ]; then cp "$license" "$1/license/"; fi
    done
    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/libglib-2.0.so" "glib.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "glib" "$ARCH" "$VER" "$LIBS_DIR_REAL/glib/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
