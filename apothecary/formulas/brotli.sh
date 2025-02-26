#!/usr/bin/env /bash
#
# Brotli is a generic-purpose lossless compression algorithm that compresses data using a combination of a modern variant of the LZ77 algorithm,
#  Huffman coding and 2nd order context modeling, with a compression ratio comparable to the best currently available general-purpose compression methods.
# It is similar in speed with deflate but offers more dense compression.
# https://github.com/google/brotli

FORMULA_TYPES=("osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "linux" "android" )
FORMULA_DEPENDS=()

# define the version
VER=1.1.0
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/google/brotli
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        # downloader ${GIT_URL}/archive/refs/tags/v${VER}.zip
        # unzip -q v${VER}.zip
        # mv brotli-${VER} brotli
        # rm -f v${VER}.zip
        git clone "$GIT_URL.git" brotli
        # https://github.com/google/brotli/issues/1105 # using git for VS due to my report fix on upstream
    else
        downloader ${GIT_URL}/archive/refs/tags/v${VER}.tar.gz
        tar -xf v${VER}.tar.gz
        mv brotli-${VER} brotli
        rm -f v${VER}.tar.gz
    fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)

    if [[ $FORCE_DOWNLOAD -eq 0 ]] && [[ $USE_SAVE == 1 ]]; then
        result=$(load "brotli" | tail -n 1)
        echoInfo "===Build $1 - Checking if Precompiled binary :[$result]==="
        if [ $result -eq 1 ]; then
            echoInfo "===Build \"$1\" Precompiled binary validated. Skipping updateFormula==="
            return 0
        else
            echoInfo "===Build Precompiled not found or outdated. Continue updateFormula for \"$1\"=== "
        fi
    else
        echoInfo "===Build  Not using cache : [FORCE_DOWNLOAD=$FORCE_DOWNLOAD] [USE_SAVE=$USE_SAVE == 1] for updateFormula \"$1\" ==="
    fi


    if [ "$TYPE" == "vs" ]; then
        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.lib
        # if [ "$PLATFORM" == "ARM64EC" ] ; then
        #   echo "ARM64EC platform detected, exiting build function."
        #   return
        # fi
        DEFINES="
          -DCMAKE_C_STANDARD=${C_STANDARD} \
          -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
          -DCMAKE_CXX_STANDARD_REQUIRED=ON \
          -DCMAKE_CXX_EXTENSIONS=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_TESTING=OFF
          "
        cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DBROTLI_DISABLE_TESTS=ON \
            -DBROTLI_BUILD_TOOLS=OFF \
            -DBROTLI_BUNDLED_MODE=OFF \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}"

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
        rm -f CMakeCache.txt
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DBROTLI_EMSCRIPTEN=OFF \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_MACOSX_BUNDLE=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_INSTALL_BINARY_DIR=lib \
            -DCMAKE_INSTALL_FULL_LIBDIR=lib \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DBROTLI_DISABLE_TESTS=ON \
            -DBROTLI_BUILD_TOOLS=OFF \
            -DBROTLI_BUNDLED_MODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [[ "$TYPE" =~ ^(linux)$ ]]; then

        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        DEFINES="
          -DCMAKE_C_STANDARD=${C_STANDARD} \
          -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
          -DCMAKE_CXX_STANDARD_REQUIRED=ON \
          -DCMAKE_CXX_EXTENSIONS=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_TESTING=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_INSTALL_BINARY_DIR=lib \
            -DCMAKE_INSTALL_FULL_LIBDIR=lib \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DBROTLI_DISABLE_TESTS=ON \
            -DBROTLI_BUILD_TOOLS=OFF \
            -DBROTLI_BUNDLED_MODE=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [[ "$TYPE" =~ ^(android)$ ]]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        DEFINES="
          -DCMAKE_C_STANDARD=${C_STANDARD} \
          -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
          -DCMAKE_CXX_STANDARD_REQUIRED=ON \
          -DCMAKE_CXX_EXTENSIONS=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_TESTING=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DPLATFORM=$PLATFORM \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DBROTLI_DISABLE_TESTS=ON \
            -DBROTLI_BUILD_TOOLS=OFF \
            -DBROTLI_BUNDLED_MODE=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_VISIBILITY=OFF

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/include
    . "$SECURE_SCRIPT"
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v -r c/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/"*.a $1/lib/$TYPE/$PLATFORM/
        secure "$1/lib/$TYPE/$PLATFORM/libbrotlidec.a" "brotli.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlicommon.pc" $1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlidec.pc" $1/lib/$TYPE/$PLATFORM/libbrotlidec.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlienc.pc" $1/lib/$TYPE/$PLATFORM/libbrotlienc.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    elif [ "$TYPE" == "vs" ]; then
        cp -v -r c/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/"*.lib $1/lib/$TYPE/$PLATFORM/
        secure "$1/lib/$TYPE/$PLATFORM/brotlidec.lib" "brotli.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlicommon.pc" $1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlidec.pc" $1/lib/$TYPE/$PLATFORM/libbrotlidec.pc
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlienc.pc" $1/lib/$TYPE/$PLATFORM/libbrotlienc.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    elif [ "$TYPE" == "linux" ]; then

        mkdir -p $1/lib/$TYPE/${PLATFORM}/
        cp -v -r c/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/"*.a $1/lib/$TYPE/${PLATFORM}/
        secure "$1/lib/$TYPE/$PLATFORM/libbrotlidec.a" "brotli.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlicommon.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlicommon.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlidec.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlidec.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlienc.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlienc.pc

        PKG_FILE="$1/lib/$TYPE/${PLATFORM}/libbrotlicommon.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    elif [ "$TYPE" == "android" ]; then

        mkdir -p $1/lib/$TYPE/${PLATFORM}/
        cp -v -r c/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/"*.a $1/lib/$TYPE/${PLATFORM}/
        secure "$1/lib/$TYPE/$PLATFORM/libbrotlidec.a" "brotli.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlicommon.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlicommon.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlidec.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlidec.pc
        cp -vR "build_${TYPE}_${PLATFORM}/libbrotlienc.pc" $1/lib/$TYPE/${PLATFORM}/libbrotlienc.pc

        PKG_FILE="$1/lib/$TYPE/${PLATFORM}/libbrotlicommon.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    fi

    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    else
        make uninstall
        make clean
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "brotli" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
