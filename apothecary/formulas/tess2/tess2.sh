#!/usr/bin/env bash
#
# tess2
# Game and tools oriented refactored version of GLU tesselator
# https://code.google.com/p/libtess2/
#
# has no build system, only an old Xcode project
# we follow the Homebrew approach which is to use CMake via a custom CMakeLists.txt
# on ios, use some build scripts adapted from the Assimp project

# define the version
FORMULA_TYPES=("osx" "vs" "emscripten" "ios" "watchos" "catos" "xros" "tvos" "android" "linux" "msys2")
FORMULA_DEPENDS=()

# define the version
VER=1.0.2
BUILD_ID=2
DEFINES=""

# tools for git use
GIT_URL=https://github.com/memononen/libtess2
GIT_TAG=master

CSTANDARD=c17            # c89 | c99 | c11 | gnu11
CPPSTANDARD=c++17        # c89 | c99 | c11 | gnu11
COMPILER_CTYPE=clang     # clang, gcc
COMPILER_CPPTYPE=clang++ # clang, gcc
STDLIB=libc++

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader $GIT_URL/archive/refs/tags/v$VER.tar.gz
    tar -xzf v$VER.tar.gz
    mv libtess2-$VER tess2
    rm v$VER.tar.gz

    # check if the patch was applied, if not then patch

    cd tess2
    patch -p1 -u -N <$FORMULA_DIR/tess2.patch
    cd ..
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    # copy in build script and CMake toolchains adapted from Assimp
    if [ "$TYPE" == "osx" ]; then
        mkdir -p build
    fi
}

# executed inside the lib src dir
function build() {
    export DEFINES="
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
	        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"

    cp -v $FORMULA_DIR/CMakeLists.txt .
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_INSTALL_INCLUDEDIR=include
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "vs" ]; then
        cp -v $FORMULA_DIR/CMakeLists.txt .
        echo "building tess2 $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.lib *.o
        cmake .. ${DEFINES} \
            -DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DBUILD_SHARED_LIBS=OFF \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_CXX_FLAGS=-DNDEBUG \
            -DCMAKE_C_FLAGS=-DNDEBUG \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [ "$TYPE" == "android" ]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake
        cp -v $FORMULA_DIR/CMakeLists.txt .

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o

        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE="Release" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_EXTENSIONS=OFF
        cmake --build . --config Release -j${PARALLEL_MAKE}
        cd ..

    elif [ "$TYPE" == "emscripten" ]; then
        cp -v $FORMULA_DIR/CMakeLists.txt .
        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt *.a *.o
        emcmake cmake .. \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_BUILD_TYPE="Release" \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCPU_BASELINE='' \
            -DCPU_DISPATCH='' \
            -DCMAKE_CXX_FLAGS_RELEASE=" ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS=" ${FLAG_RELEASE}" \
            -DCMAKE_CXX_FLAGS=" ${FLAG_RELEASE}"
        $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}${PARALLEL_MAKE}
    elif [ "$TYPE" == "msys2" ]; then
        cp -v $FORMULA_DIR/CMakeLists.txt .
        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt *.a *.o
        export DEFINES="${DEFINES} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"

        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_VERBOSE_MAKEFILE=TRUE

        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [ "$TYPE" == "linux" ]; then
        cp -v $FORMULA_DIR/CMakeLists.txt .
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh $ABI
        fi
        echoVerbose "building $TYPE | $ARCH | $PLATFORM"
        echoVerbose "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.so
        export DEFINES="${DEFINES} \
            -DLIBRARY_SUFFIX=${ABI} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
	        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DZLIB_BUILD_EXAMPLES=OFF \
            -DSKIP_EXAMPLE=ON \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=TRUE
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    else
        mkdir -p build/$TYPE
        cd build/$TYPE
        cmake -G "Unix Makefiles" -DCMAKE_CXX_COMPILER=/mingw32/bin/g++.exe \
            -DCMAKE_C_COMPILER=/mingw32/bin/gcc.exe \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_FLAGS=-DNDEBUG \
            -DCMAKE_C_FLAGS=-DNDEBUG ../../
        make
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    rm -rf $1/include
    mkdir -p $1/include
    cp -Rv Include/* $1/include/
    . "$SECURE_SCRIPT"
    mkdir -p $1/lib/$TYPE
    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/
        cp -f "build_${TYPE}_${PLATFORM}/Release/lib/tess2.lib" $1/lib/$TYPE/$PLATFORM/tess2.lib
        secure "$1/lib/$TYPE/$PLATFORM/tess2.lib" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libtess2.a" $1/lib/$TYPE/$PLATFORM/libtess2.a
        secure "$1/lib/$TYPE/$PLATFORM/libtess2.a" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/libtess2.a" $1/lib/$TYPE/$PLATFORM/libtess2.a
        secure "$1/lib/$TYPE/$PLATFORM/libtess2.a" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "msys2" ]; then
        mkdir -p $1/lib/$TYPE/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/
        cp -v "build_${TYPE}_${PLATFORM}/libtess2.a" $1/lib/$TYPE/libtess2.a
        secure "$1/lib/$TYPE/libtess2.a" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        echo "libtess2.a" > $1/lib/$TYPE/libsorder.make
    elif [ "$TYPE" == "android" ]; then
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -v "build_${TYPE}_${PLATFORM}/libtess2.a" $1/lib/$TYPE/$PLATFORM/libtess2.a
        secure "$1/lib/$TYPE/$PLATFORM/libtess2.a" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    else
        cp -v build/$TYPE/libtess2.a $1/lib/$TYPE/libtess2.a
        secure "$1/lib/$TYPE/$PLATFORM/libtess2.a" "tess2.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten|linux)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    else
        make clean
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "tess2" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
