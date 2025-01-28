#!/usr/bin/env bash
#
# GStreamer

# Define the version
FORMULA_TYPES=("linux" "osx" )

FORMULA_DEPENDS=( "freetype" "libpng" "zlib" )

VER=1.24.0
GIT_URL=https://gitlab.freedesktop.org/gstreamer/gstreamer.git

DEFINES=""
BUILD_ID=1

function download() {
    . "$DOWNLOADER_SCRIPT"
    FILE_NAME=gstreamer

    if [ -d $FILE_NAME ]; then
        echo "Directory $FILE_NAME already exists. Pulling latest changes."
        cd $FILE_NAME
        git pull origin main
        cd ..
    else
        git clone --depth=1 --branch main $GIT_URL $FILE_NAME
    fi

    echo "prepare gstreamer install apts"
    sudo apt-get update
    sudo apt-get install -y \
        git \
        ninja-build \
        pkg-config \
        gcc \
        g++ \
        python3 \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        libglib2.0-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev
    echo "Preparation complete"
    pip install --user --upgrade meson --break-system-packages
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
}

function prepare() {
    echo "prepare meson"
    meson --version


}

function build() {
    echo "build gstreamer"
    LIBS_ROOT=$(realpath $LIBS_DIR)


    ZLIB_ROOT="$LIBS_ROOT/zlib/"
    ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
    ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

    LIBPNG_ROOT="${LIBS_ROOT}/libpng/"
    LIBPNG_INCLUDE_DIR="${LIBS_ROOT}/libpng/include"
    LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/${TYPE}/${PLATFORM}/libpng16.a"

    FREETYPE_ROOT="${LIBS_ROOT}/freetype/"
    FREETYPE_INCLUDE_DIR="${LIBS_ROOT}/freetype/include"
    FREETYPE_LIBRARY="$LIBS_ROOT/freetype/lib/${TYPE}/${PLATFORM}/libfreetype.a"

    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM:${FREETYPE_ROOT}/lib/$TYPE/$PLATFORM"

    pkg-config --modversion libpng
    pkg-config --modversion zlib
    pkg-config --modversion freetype
    pkg-config --modversion gstreamer-1.0
    pkg-config --modversion gstreamer-app-1.0
    pkg-config --modversion gstreamer-video-1.0

    BUILD_DIR="build_${TYPE}_${PLATFORM}"
    mkdir -p "$BUILD_DIR"

    meson setup "$BUILD_DIR" \
    --cross-file "$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.meson.ini" \
    --buildtype=release \
    --default-library=static \
    --backend=ninja \
    -Dgst-full-libraries=video \
    -Dc_args="-I${LIBPNG_INCLUDE_DIR} -I${ZLIB_INCLUDE_DIR} -I${FREETYPE_INCLUDE_DIR}" \
    -Dc_link_args="${LIBPNG_LIBRARY} ${ZLIB_LIBRARY} ${FREETYPE_LIBRARY} -lm" \
    -Dcpp_link_args="${LIBPNG_LIBRARY} ${ZLIB_LIBRARY} ${FREETYPE_LIBRARY} -lm"

    ninja -C "$BUILD_DIR"
    ninja install -C "$BUILD_DIR"
    cd ..
}

function copy() {
    mkdir -p $1/include
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/lib/$TYPE/$PLATFORM/

    cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/
    cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib" $1/lib/$TYPE/$PLATFORM/
    cp -Rv "build_${TYPE}_${PLATFORM}/Release/share" $1/$TYPE/$PLATFORM/share/
}

function clean() {
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        rm -r build_${TYPE}_${PLATFORM}
    fi
}

function save() {
    . "$SAVE_SCRIPT"
    savestatus ${TYPE} "gstreamer" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "gstreamer" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
