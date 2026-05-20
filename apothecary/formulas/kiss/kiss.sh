#!/usr/bin/env bash
#
# KissFFT
# "Keep It Simple, Stupid" Fast Fourier Transform
# http://sourceforge.net/projects/kissfft/

FORMULA_TYPES=("linux" "msys2")
FORMULA_DEPENDS=()

# define the version
VER=131.1.0
BUILD_ID=1

# tools for git use
GIT_URL=https://github.com/mborgerding/kissfft.git
GIT_TAG=v$VER
URL=https://github.com/mborgerding/kissfft/archive/refs/tags/${VER}
DEFINES=""

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    # echo "Running: git clone --branch ${GIT_TAG} ${GIT_URL}"
    # git clone --branch ${GIT_TAG} ${GIT_URL}

    echo "${URL}"
    downloader "${URL}.tar.gz"
    tar -xf "${VER}.tar.gz"
    mv "kissfft-${VER}" kissfft
    rm "${VER}.tar.gz"
    mv kissfft kiss
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo ""

    apothecaryDepend download zlib
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib

    apothecaryDepend download libpng
    apothecaryDepend prepare libpng
    apothecaryDepend build libpng
    apothecaryDepend copy libpng

    rm -f ./CMakeLists.txt
    cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)
    if [ "$TYPE" == "linux" ]; then
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        rm -f CMakeCache.txt *.a *.o *.so

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        DEFINES="${DEFINES} -DLIBRARY_SUFFIX=${ARCH} \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
            -DKISSFFT_STATIC=ON \
            -DKISSFFT_TEST=OFF \
            -DKISSFFT_TOOLS=ON \
            -DKISSFFT_OPENMP=OFF \
            -DKISSFFT_PKGCONFIG=ON"
        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=true
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [ "$TYPE" == "msys2" ]; then
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        if [ $CROSSCOMPILING -eq 1 ]; then
            DEFINES="${DEFINES} -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake"
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.so


        DEFINES="${DEFINES} -DLIBRARY_SUFFIX=${ARCH} \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
            -DKISSFFT_STATIC=ON \
            -DKISSFFT_TEST=OFF \
            -DKISSFFT_TOOLS=ON \
            -DKISSFFT_OPENMP=OFF \
            -DKISSFFT_PKGCONFIG=ON"
        cmake .. ${DEFINES} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=true
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # headers
    mkdir -p $1/include
    cp -v kiss_fft.h $1/include
    # cp -v tools/kiss_fftr.h $1/include
    . "$SECURE_SCRIPT"

    mkdir -p $1/lib/$TYPE
    if [ "$TYPE" == "linux" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libkissfft-float.a" $1/lib/$TYPE/$PLATFORM/libkiss.a
        secure "$1/lib/$TYPE/$PLATFORM/libkiss.a" "kiss.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
    elif [ "$TYPE" == "msys2" ]; then
        mkdir -p $1/lib/$TYPE
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libkissfft-float.a" $1/lib/$TYPE/libkiss.a
        secure "$1/lib/$TYPE/libkiss.a" "kiss.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
        echo "libkiss.a" > $1/lib/$TYPE/libsorder.make
    else
        cp -v lib/$TYPE/libkiss.a $1/lib/$TYPE/libkiss.a
    fi

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
    if [[ "$TYPE" =~ ^(linux|msys2)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "kiss" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
