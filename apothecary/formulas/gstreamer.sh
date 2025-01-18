#!/usr/bin/env bash
#
# GStreamer

# Define the version
FORMULA_TYPES=("linux" "osx" )

FORMULA_DEPENDS=()

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
}

function prepare() {
    echo "prepare gstreamer install apts"
    sudo apt-get update
    sudo apt-get install -y \
        git \
        meson \
        ninja-build \
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
}

function build() {
    echo "build gstreamer"
    LIBS_ROOT=$(realpath $LIBS_DIR)

    mkdir -p "build_${TYPE}_${PLATFORM}"
    # cd "build_${TYPE}_${PLATFORM}"
    # using Menson build system
    meson setup .. \
        --prefix="${LIBS_ROOT}/gstreamer/Release" \
        --buildtype=release \
        --default-library=static \
        -Dgst-full-libraries=app,video\
        build_${TYPE}_${PLATFORM}

                # meson -Dauto_features=disabled -Dgstreamer:tools=enabled -Dbad=enabled -Dgst-plugins-bad:openh264=enabled


    ninja
    ninja install
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
