#!/usr/bin/env bash
#
# json
# JSON for Modern C++ http://nlohmann.github.io/json
# https://github.com/nlohmann/json
#

FORMULA_TYPES=("osx" "msys2" "linux" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")
FORMULA_DEPENDS=()

# define the version
VER=3.11.3
BUILD_ID=3
DEFINES=""

# tools for git use
GIT_URL=https://github.com/nlohmann/json
GIT_TAG=v$VER
URL=${GIT_URL}/archive/refs/tags/v$VER.tar.gz

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"

    if [ "$PLATFORM" == "msys2" ] || [ "$PLATFORM" == "vs" ]; then
        mkdir json
        cd json
        downloader "${GIT_URL}/releases/download/v$VER/include.zip"
        unzip include.zip
        rm include.zip
    else
        downloader "${URL}"
        tar -xf "v${VER}.tar.gz"
        mv "json-${VER}" json
        rm v$VER.tar.gz
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
    # nothing to do
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # headers
    mkdir -p $1/include/nlohmann
    cp -v single_include/nlohmann/json.hpp $1/include/nlohmann/json.hpp

    . "$SECURE_SCRIPT"

    secure "$1/include/nlohmann/json.hpp" "json.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE.MIT $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "linux" -o "$TYPE" == "linux64" ]; then
        rm -f *.hpp *:MIT
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "json" ${ARCH} ${VER} "$LIBS_DIR_REAL/json/include/nlohmann" ${PLATFORM})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
