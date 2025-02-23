#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=("osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")
FORMULA_DEPENDS=()

VER=0.9.7
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/uriparser/uriparser
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
    git clone $GIT_URL uriparser
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "prepare"
    rm -f ./CMakeLists.txt
    cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt
}

# executed inside the lib src dir
function build() {
    echo "uriparser build"
    LIBS_ROOT=$(realpath $LIBS_DIR)
    DEFS=" 
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=OFF \
 			-DURIPARSER_BUILD_WCHAR_T=ON \
 			-DURIPARSER_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
 			-DDBUILD_SHARED_LIBS=OFF \
			-DURIPARSER_BUILD_CHAR=ON \
			-DURIPARSER_ENABLE_INSTALL=OFF \
			-DURIPARSER_WARNINGS_AS_ERRORS=OFF
	   "
    export DEFINES="$DEFS "
    if [ "$TYPE" == "vs" ]; then
        echo "building uriparser $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.lib
        EXTRA_DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DURIPARSER_ENABLE_INSTALL=ON \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"
        cmake .. ${DEFS} \
            ${EXTRA_DEFS} \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [ "$TYPE" == "android" ]; then
        echo "Android "
        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        mkdir -p "build_${TYPE}_${ABI}"
        cd "build_${TYPE}_${ABI}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DURIPARSER_ENABLE_INSTALL=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        echo "int main(){return 0;}" >tool/uriparse.c
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            ${DEFS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -D_GNU_SOURCE" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -D_GNU_SOURCE" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DHAVE_REALLOCARRAY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_VISIBILITY=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
        cmake --build . --config Release -j${PARALLEL_MAKE}
        rm -f CMakeCache.txt
        cd ..

    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -B . \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_CXX_FLAGS="-std=c++${CPP_STANDARD}  ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-std=c${C_STANDARD} ${FLAG_RELEASE}"
        # cmake --build . --config Release -j${PARALLEL_MAKE}
        $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # prepare headers directory if needed
    mkdir -p $1/include/uriparser
    # prepare libs directory if needed
    mkdir -p $1/lib/$TYPE
    . "$SECURE_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R "build_${TYPE}_${ARCH}/Release/include/" $1/
        cp -Rv "build_${TYPE}_${ARCH}/UriConfig.h" $1/include/uriparser/
        cp -f "build_${TYPE}_${ARCH}/Release/lib/uriparser.lib" $1/lib/$TYPE/$PLATFORM/uriparser.lib
        secure "$1/lib/$TYPE/$PLATFORM/uriparser.lib" "uriparser.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        cp -R include/uriparser/* $1/include/uriparser/
        cp -Rv "build_${TYPE}_${PLATFORM}/UriConfig.h" $1/include/uriparser/
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${PLATFORM}/liburiparser.a $1/lib/$TYPE/$PLATFORM/uriparser.a
        secure "$1/lib/$TYPE/$PLATFORM/uriparser.a" "uriparser.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/lib/$TYPE/${PLATFORM}
        cp -R include/uriparser/* $1/include/uriparser/
        cp -Rv "build_${TYPE}_${PLATFORM}/UriConfig.h" $1/include/uriparser/
        cp -Rv "build_${TYPE}_${PLATFORM}/liburiparser.a" $1/lib/$TYPE/${PLATFORM}/uriparser.a
        secure "$1/lib/$TYPE/$PLATFORM/uriparser.a" "uriparser.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "android" ]; then
        cp -R include/uriparser/* $1/include/uriparser/
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${ABI}/liburiparser.a $1/lib/$TYPE/$PLATFORM/liburiparser.a
        secure "$1/lib/$TYPE/$PLATFORM/liburiparser.a" "uriparser.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${ABI}" ]; then
            rm -r build_${TYPE}_${ABI}
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    else
        make clean
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "uriparser" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
