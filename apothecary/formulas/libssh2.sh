#!/usr/bin/env bash
#
# libssh2

# Define the version
FORMULA_TYPES=()

FORMULA_DEPENDS=("zlib" "openssl")

VER=1.11.0-dev
GIT_URL=https://github.com/libssh2/libssh2.git

DEFINES=""
BUILD_ID=1

function download() {
    . "$DOWNLOADER_SCRIPT"
    FILE_NAME=libssh2

    if [ -d $FILE_NAME ]; then
        echo "Directory $FILE_NAME already exists. Pulling latest changes."
        cd $FILE_NAME
        git pull origin master
        cd ..
    else
        git clone --depth=1 --branch master $GIT_URL $FILE_NAME
    fi
}

function prepare() {
    apothecaryDependencies download
    echo "Preparation complete"
}

function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)

    mkdir -p "build_${TYPE}_${PLATFORM}"
    cd "build_${TYPE}_${PLATFORM}"

    cmake .. \
        -DCMAKE_C_FLAGS="${DEFINES}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
        -DCMAKE_INSTALL_PREFIX=Release

    cmake --build . --config Release -j${PARALLEL_MAKE} --target install
    cd ..

}

function copy() {
    mkdir -p $1/include
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/lib/$TYPE/$PLATFORM/

    cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libssh2.a" $1/lib/$TYPE/$PLATFORM/libssh2.a
    cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/
    cp -v LICENSE $1/license/
}

function clean() {
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        rm -r build_${TYPE}_${PLATFORM}
    fi
}

function save() {
    . "$SAVE_SCRIPT"
    savestatus ${TYPE} "libssh2" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "libssh2" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
