#!/usr/bin/env bash
# Linux modular gtk3: preserves the upstream gtk+-3.0 pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=3.24.52
BUILD_ID=2
GIT_URL="https://download.gnome.org/sources/gtk/3.24/gtk-3.24.52.tar.xz"
SHA256=80931fa472a77b9a164f6740e3c0b444fac6770054632d35a7ff9d679e5e7b9f
DEFINES="-Dgtk_doc=false -Dintrospection=false -Dman=false -Ddemos=false -Dexamples=false -Dtests=false -Dinstalled_tests=false -Dx11_backend=true -Dwayland_backend=true -Dprint_backends=file"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://download.gnome.org/sources/gtk/3.24/gtk-3.24.52.tar.xz"
    verify_sha256 "gtk-3.24.52.tar.xz" "$SHA256"
    tar -xf "gtk-3.24.52.tar.xz"
    mv "gtk-3.24.52" gtk3
    rm -f "gtk-3.24.52.tar.xz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Dgtk_doc=false -Dintrospection=false -Dman=false -Ddemos=false -Dexamples=false -Dtests=false -Dinstalled_tests=false -Dx11_backend=true -Dwayland_backend=true -Dprint_backends=file
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
    secure "$1/lib/$TYPE/$PLATFORM/libgtk-3.so" "gtk3.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "gtk3" "$ARCH" "$VER" "$LIBS_DIR_REAL/gtk3/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
