#!/usr/bin/env bash
# Linux modular openal: preserves the upstream openal pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=1.25.2
BUILD_ID=2
GIT_URL="https://github.com/kcat/openal-soft/archive/refs/tags/1.25.2.tar.gz"
SHA256=fb27e5839aa11f0e5b9d33756965291fad5d6909ab928ea1f796f4a1a6877894
DEFINES="-DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DALSOFT_TESTS=OFF -DALSOFT_ENABLE_MODULES=OFF"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://github.com/kcat/openal-soft/archive/refs/tags/1.25.2.tar.gz"
    verify_sha256 "1.25.2.tar.gz" "$SHA256"
    tar -xf "1.25.2.tar.gz"
    mv "openal-soft-1.25.2" openal
    rm -f "1.25.2.tar.gz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    cmake -S . -B "$bdir" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DALSOFT_EXAMPLES=OFF -DALSOFT_UTILS=OFF -DALSOFT_TESTS=OFF -DALSOFT_ENABLE_MODULES=OFF
    cmake --build "$bdir" --parallel "${PARALLEL_MAKE:-2}"
    cmake --install "$bdir"
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
    secure "$1/lib/$TYPE/$PLATFORM/libopenal.so" "openal.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "openal" "$ARCH" "$VER" "$LIBS_DIR_REAL/openal/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
