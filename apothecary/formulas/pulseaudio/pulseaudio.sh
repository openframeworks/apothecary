#!/usr/bin/env bash
# Linux modular pulseaudio: preserves the upstream libpulse-simple pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=17.0
BUILD_ID=1
SHA256=053794d6671a3e397d849e478a80b82a63cb9d8ca296bd35b73317bb5ceb87b5
DEFINES="-Ddaemon=false -Dclient=true -Dtests=false -Ddoxygen=false -Dman=false -Ddatabase=simple -Ddbus=disabled -Dsystemd=disabled -Dudev=disabled -Dbluez5=disabled -Davahi=disabled -Dalsa=disabled -Dgtk=disabled -Dglib=disabled -Dx11=disabled"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://www.freedesktop.org/software/pulseaudio/releases/pulseaudio-17.0.tar.xz"
    verify_sha256 "pulseaudio-17.0.tar.xz" "$SHA256"
    tar -xf "pulseaudio-17.0.tar.xz"
    mv "pulseaudio-17.0" pulseaudio
    rm -f "pulseaudio-17.0.tar.xz"
}

function prepare() {
    # Client libraries must locate their private common library after download.
    sed "s/install_rpath : privlibdir/install_rpath : '\$ORIGIN\/pulseaudio'/g" src/pulse/meson.build > src/pulse/meson.build.tmp
    mv src/pulse/meson.build.tmp src/pulse/meson.build
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    meson setup "$bdir" --prefix="$prefix" --libdir=lib --buildtype=release \
        --default-library=shared --wrap-mode=nofallback -Ddaemon=false -Dclient=true -Dtests=false -Ddoxygen=false -Dman=false -Ddatabase=simple -Ddbus=disabled -Dsystemd=disabled -Dudev=disabled -Dbluez5=disabled -Davahi=disabled -Dalsa=disabled -Dgtk=disabled -Dglib=disabled -Dx11=disabled
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
    secure "$1/lib/$TYPE/$PLATFORM/libpulse.so" "pulseaudio.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "pulseaudio" "$ARCH" "$VER" "$LIBS_DIR_REAL/pulseaudio/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
