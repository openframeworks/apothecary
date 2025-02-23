#!/usr/bin/env bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

FORMULA_TYPES=("vs" "osx" "emscripten" "ios" "watchos" "catos" "xros" "tvos" "linux" "android")
FORMULA_DEPENDS=()

# define the version
VER=1.3.1
BUILD_ID=2
DEFINES=""
FRAMEWORKS=""

# tools for git use
GIT_URL=https://github.com/madler/zlib/releases/download/v$VER/zlib-$VER.tar.gz
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"

    downloader ${GIT_URL}
    tar -xf zlib-$VER.tar.gz
    mv zlib-$VER zlib
    rm -f zlib-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
    # . "$DOWNLOADER_SCRIPT"
    # downloader https://github.com/danoli3/zlib/raw/patch-1/CMakeLists.txt
    cp -v "$FORMULA_DIR"/*.txt ./

}

function load() {
    if [ -f "$LOAD_SCRIPT" ]; then
        source "$LOAD_SCRIPT"
    else
        return 0
    fi
    # Call the actual loadsave function
    LOAD_RESULT=$(loadsave "${TYPE}" "zlib" "${ARCH}" "${VER}" "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" "${BUILD_ID}")

    # Extract last line to get result
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)

    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)

    if [[ $FORCE_DOWNLOAD -eq 0 ]] && [[ $USE_SAVE == 1 ]]; then
        result=$(load "zlib" | tail -n 1)
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

        echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoVerbose "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.lib *.o *.a
        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}"
        cmake .. \
            -G "${GENERATOR_NAME}" \
            -A "${PLATFORM}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -D BUILD_SHARED_LIBS=ON \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            ${CMAKE_WIN_SDK}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -D BUILD_SHARED_LIBS=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [ "$TYPE" == "android" ]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        mkdir -p "build_${TYPE}_${ABI}"
        cd "build_${TYPE}_${ABI}"
        rm -f CMakeCache.txt *.a *.o

        DEFINES="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt *.a *.o *.js
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DLINK_FLAGS="${LINK_FLAGS}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -D BUILD_SHARED_LIBS=OFF \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS=" ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="${FLAG_RELEASE}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -G 'Unix Makefiles'
        #     -DCMAKE_INSTALL_INCLUDEDIR=include
        # $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        # $EMSDK/upstream/emscripten/emmake make install
        # cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        $EMSDK/upstream/emscripten/emmake make install
        cd ..
    elif [ "$TYPE" == "msys2" ]; then
        echoVerbose "building $TYPE | $ARCH "
        echoVerbose "--------------------"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.so
        DEFINES="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_SYSTEM_PROCESSOR=$ARCH \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [ "$TYPE" == "linux" ]; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        echoVerbose "building $TYPE | $ARCH "
        echoVerbose "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.so
        DEFINES="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    mkdir -p $1/include
    . "$SECURE_SCRIPT"
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/ >/dev/null 2>&1
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a
        secure "$1/lib/$TYPE/$PLATFORM/zlib.a" "zlib.a" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "vs" ]; then
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/ >/dev/null 2>&1
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/z.lib" $1/lib/$TYPE/$PLATFORM/zlib.lib >/dev/null 2>&1
        secure "$1/lib/$TYPE/$PLATFORM/zlib.lib" "zlib.lib" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -vR "build_${TYPE}_${ARCH}/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -v "build_${TYPE}_${ABI}/Release/lib/libz.a" $1/lib/$TYPE/${PLATFORM}/zlib.a
        cp -RT "build_${TYPE}_${ABI}/Release/include/" $1/include
        secure "$1/lib/$TYPE/${PLATFORM}/zlib.a" "zlib.a" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -v "build_${TYPE}_$PLATFORM/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/${PLATFORM}/zlib.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${ABI}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$ABI"

    elif [ "$TYPE" == "emscripten" ]; then
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/
        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -v "build_${TYPE}_$PLATFORM/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a
        secure "$1/lib/$TYPE/$PLATFORM/zlib.a" "zlib.a" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -v "build_${TYPE}_$PLATFORM/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/zlib.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "linux" ]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/ >/dev/null 2>&1
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a >/dev/null 2>&1
        secure "$1/lib/$TYPE/$PLATFORM/zlib.a" "zlib.a" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -v "build_${TYPE}_$PLATFORM/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/zlib.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "msys2" ]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/ >/dev/null 2>&1
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a >/dev/null 2>&1
        secure "$1/lib/$TYPE/$PLATFORM/zlib.a" "zlib.a" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    else
        make install
    fi

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
    if [[ "$TYPE" =~ ^(vs|osx|ios|tvos|xros|catos|watchos|emscripten|linux)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${ABI}" ]; then
            rm -r build_${TYPE}_${ABI}
        fi
    elif [ "$TYPE" == "msys2" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    else
        make uninstall
        make clean
    fi
}


