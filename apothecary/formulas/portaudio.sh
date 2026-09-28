#!/usr/bin/env bash
#
# PortAudio
# Portable Cross-platform Audio I/O
# http://www.portaudio.com/
#
# build not currently needed on any platform

FORMULA_TYPES=("linux")
FORMULA_DEPENDS=()

# define the version
VER=stable_v19_20110326
SHA256=328a89adc42c66840641d2d557d01e8bd9e6be32e12d3802e3b638e0791de540
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=
GIT_TAG=

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    if ! downloader "https://files.portaudio.com/archives/pa_$VER.tgz"; then
        echoWarning "PortAudio download service unavailable; trying legacy archive host"
        downloader "http://www.portaudio.com/archives/pa_$VER.tgz"
    fi
    verify_sha256 "pa_$VER.tgz" "$SHA256"
    tar -xf pa_$VER.tgz
    rm pa_$VER.tgz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    local automake_libdir
    automake_libdir="$(automake --print-libdir)"
    cp "$automake_libdir/config.guess" "$automake_libdir/config.sub" .
}

# executed inside the lib src dir
function build() {
    local BUILD_TRIPLET
    BUILD_TRIPLET="$(gcc -dumpmachine)"
    local HOST_ARGS=()
    if [ -n "${TOOLCHAIN_PREFIX:-}" ]; then
        HOST_ARGS=(--host="$TOOLCHAIN_PREFIX")
    fi
    ./configure \
        --build="$BUILD_TRIPLET" \
        "${HOST_ARGS[@]}" \
        --prefix="$PWD/build_${TYPE}_${PLATFORM}/Release" \
        --disable-shared \
        --enable-static \
        --without-jack
    make -j"${PARALLEL_MAKE}"
    make install
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -p $1/include
    cp -Rv include/* $1/include
    mkdir -p "$1/lib/$TYPE/$PLATFORM"
    cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libportaudio.a" "$1/lib/$TYPE/$PLATFORM/libportaudio.a"
    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/libportaudio.a" "portaudio.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {
    make clean
}
