#!/usr/bin/env bash
# Linux modular fontconfig: preserves the upstream fontconfig pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=2.18.3
BUILD_ID=2
GIT_URL="https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz"
SHA256=4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3
DEFINES="-Ddoc=disabled -Dtests=disabled -Dcache-build=disabled -Dfontations=disabled"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz"
    verify_sha256 "fontconfig-2.18.3.tar.xz" "$SHA256"
    tar -xf "fontconfig-2.18.3.tar.xz"
    mv "fontconfig-2.18.3" fontconfig
    rm -f "fontconfig-2.18.3.tar.xz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Ddoc=disabled -Dtests=disabled -Dcache-build=disabled -Dfontations=disabled
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
    secure "$1/lib/$TYPE/$PLATFORM/libfontconfig.so" "fontconfig.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "fontconfig" "$ARCH" "$VER" "$LIBS_DIR_REAL/fontconfig/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
