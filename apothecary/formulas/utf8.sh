#!/usr/bin/env bash
#
# utf8cpp
#
#
FORMULA_TYPES=("osx" "msys2" "linux" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")
FORMULA_DEPENDS=()

# define the version
VER=4.0.6
VER_=4_0_6
BUILD_ID=2
DEFINES=""

# tools for git use
GIT_URL=https://github.com/nemtrif/utfcpp
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        downloader ${GIT_URL}/archive/refs/tags/v${VER}.zip
        unzip -q v${VER}.zip
        mv utfcpp-${VER} utf8
        rm v${VER}.zip
    else
        downloader ${GIT_URL}//archive/refs/tags/v${VER}.tar.gz
        tar -xf v${VER}.tar.gz
        mv utfcpp-${VER} utf8
        rm -f v${VER}.tar.gz
    fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo
    # nothing to do
}

# executed inside the lib src dir
function build() {
    echo
    #nothing to do, header only lib
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # headers
    mkdir -p $1/include
    cp -vr source/* $1/include

    . "$SECURE_SCRIPT"
    secure "$1/include/utf8.h" "glm.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
    echo
    #nothing to do header ony lib
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "utf8" ${ARCH} ${VER} "$LIBS_DIR_REAL/utf8/include" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
