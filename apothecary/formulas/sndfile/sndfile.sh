#!/usr/bin/env bash
# Linux modular sndfile: preserves the upstream sndfile pkg-config interface.
FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()
VER=1.2.2
BUILD_ID=2
GIT_URL="https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz"
SHA256=3799ca9924d3125038880367bf1468e53a1b7e3686a934f098b7e1d286cdb80e
DEFINES="-DBUILD_TESTING=OFF -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DENABLE_EXTERNAL_LIBS=ON -DENABLE_MPEG=ON"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz"
    verify_sha256 "libsndfile-1.2.2.tar.xz" "$SHA256"
    tar -xf "libsndfile-1.2.2.tar.xz"
    mv "libsndfile-1.2.2" sndfile
    rm -f "libsndfile-1.2.2.tar.xz"
}

function prepare() {
    :
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" prefix
    prefix="$PWD/$bdir/Release"
    cmake -S . -B "$bdir" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_INSTALL_PREFIX="$prefix" -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_TESTING=OFF -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DENABLE_EXTERNAL_LIBS=ON -DENABLE_MPEG=ON
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
    secure "$1/lib/$TYPE/$PLATFORM/libsndfile.so" "sndfile.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "sndfile" "$ARCH" "$VER" "$LIBS_DIR_REAL/sndfile/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    echo "$LOAD_RESULT" | tail -n 1
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}
