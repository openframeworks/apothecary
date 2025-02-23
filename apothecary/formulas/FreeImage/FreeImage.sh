#!/usr/bin/env bash
#
# Free Image
# cross platform image io
# http://freeimage.sourceforge.net
#
# Makefile build system,
# some Makefiles are out of date so patching/modification may be required

FORMULA_TYPES=("osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" "linux")

# define the version

FORMULA_DEPENDS=("zlib" "libpng")

VER=31991
GIT_URL=https://github.com/danoli3/FreeImage
GIT_TAG=3.19.10
BUILD_ID=1
DEFINES=""

# download the source code and unpack it into LIB_NAME
function download() {

    echo " $APOTHECARY_DIR downloading $GIT_TAG"
    . "$DOWNLOADER_SCRIPT"

    URL="$GIT_URL/archive/refs/tags/$GIT_TAG.tar.gz"
    # For win32, we simply download the pre-compiled binaries.
    curl -sSL -o FreeImage-$GIT_TAG.tar.gz $URL

    tar -xzf FreeImage-$GIT_TAG.tar.gz
    mv FreeImage-$GIT_TAG FreeImage
    rm FreeImage-$GIT_TAG.tar.gz

}

# prepare the build environment, executed inside the lib src dir
function prepare() {

    if [ "$TYPE" == "android" ]; then
        local BUILD_TO_DIR=$BUILD_DIR/FreeImage
        cd $BUILD_DIR/FreeImage
        perl -pi -e "s/#define HAVE_SEARCH_H/\/\/#define HAVE_SEARCH_H/g" Source/LibTIFF4/tif_config.h

        #rm Source/LibWebP/src/dsp/dec_neon.c

        perl -pi -e "s/#define WEBP_ANDROID_NEON/\/\/#define WEBP_ANDROID_NEON/g" Source/LibWebP/./src/dsp/dsp.h

    elif [ "$TYPE" == "vs" ]; then
        echo "vs"
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "FreeImage" ${ARCH} ${VER} "$LIBS_DIR_REAL/FreeImage/lib/$TYPE/$PLATFORM" ${BUILD_ID})
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
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        DEFS="
		        -DBUILD_SHARED_LIBS=OFF \
		        -DCMAKE_INSTALL_INCLUDEDIR=include \
		        -DBUILD_LIBRAWLITE=OFF \
				-DBUILD_OPENEXR=OFF \
				-DBUILD_WEBP=ON \
				-DBUILD_JXR=OFF \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake
		        "
        cmake .. ${DEFS} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_ZLIB=OFF \
            -DBUILD_TESTS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -GXcode \
            -DPLATFORM=$PLATFORM

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [[ "$TYPE" =~ ^(linux)$ ]]; then
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        DEFS="
                -DBUILD_SHARED_LIBS=OFF \
                -DCMAKE_INSTALL_INCLUDEDIR=include \
                -DBUILD_LIBRAWLITE=OFF \
                -DBUILD_OPENEXR=OFF \
                -DBUILD_WEBP=ON \
                -DBUILD_JXR=OFF \
                -DENABLE_ARC=OFF \
                -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
                -DENABLE_VISIBILITY=OFF \
                -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
                "
        cmake .. ${DEFS} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DBUILD_ZLIB=OFF \
            -DBUILD_TESTS=OFF \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPLATFORM=$PLATFORM

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    elif [ "$TYPE" == "android" ]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        rm -rf "build__${TYPE}_${ABI}/"
        mkdir -p "build__${TYPE}_$ABI"
        cd "./build__${TYPE}_$ABI"
        rm -f CMakeCache.txt *.a *.o

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$ABI/libpng.a"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$ABI/zlib.a"

        cmake .. ${DEFINES} \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
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
            -DCMAKE_INCLUDE_PATH="${LIBPNG_INCLUDE_DIR}:${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBPNG_LIBRARY}:${ZLIB_LIBRARY}" \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
            -DDISABLE_PERF_MEASUREMENT=ON \
            -DLIBRAW_LIBRARY_BUILD=ON \
            -DLIBRAW_NODLL=ON \
            -DENABLE_VISIBILITY=OFF \
            -DDHAVE_UNISTD_H=OFF \
            -DPNG_ARM_NEON_OPT=OFF \
            -DNDEBUG=OFF \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_LIBRAWLITE=OFF \
            -DBUILD_OPENEXR=OFF \
            -DBUILD_WEBP=OFF \
            -DBUILD_JXR=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "vs" ]; then
        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN platform: $PLATFORM"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.lib
        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        	-DCMAKE_INSTALL_INCLUDEDIR=include \
        	-DBUILD_LIBRAWLITE=OFF \
        	-DBUILD_LIBPNG=OFF \
			-DBUILD_OPENEXR=OFF \
			-DBUILD_WEBP=OFF \
			-DBUILD_JXR=OFF \
			-DENABLE_VISIBILITY=OFF \
			-DPNG_ROOT=${LIBPNG_ROOT} \
			-DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
			-DBUILD_SHARED_LIBS=OFF"
        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}"
        cmake .. ${DEFS} \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_INSTALL_LIBDIR="build_${TYPE}_${ARCH}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -D CMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_INSTALL_PREFIX=. \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}

        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}"
        cmake .. ${DEFS} \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}" \
            -DCMAKE_INSTALL_LIBDIR="build_${TYPE}_${ARCH}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -D CMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_INSTALL_PREFIX=. \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"

        cmake --build . --target install --config Debug
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p build_$TYPE
        cd build_$TYPE

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng16.a"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B build \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DLINK_FLAGS="${LINK_FLAGS}" \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_LIBRAWLITE=OFF \
            -DBUILD_OPENEXR=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DBUILD_WEBP=OFF \
            -DBUILD_JXR=OFF \
            -DBUILD_TESTS=OFF \
            -DCMAKE_CXX_FLAGS=" ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS="${FLAG_RELEASE} " \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_ZLIB=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include
        #$EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        #$EMSDK/upstream/emscripten/emmake make install
        cmake --build build --target install --config Release
        cd ..
    else
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake -S . -B build \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DBUILD_LIBRAWLITE=OFF \
            -DBUILD_OPENEXR=OFF \
            -DBUILD_WEBP=OFF \
            -DBUILD_JXR=OFF \
            -DBUILD_LIBPNG=ON \
            -DBUILD_ZLIB=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            cmake --build build --target install --config Release
        cd ..

    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    if [ -d $1/include ]; then
        rm -rf $1/include
    fi
    mkdir -p $1/include
    . "$SECURE_SCRIPT"
    # lib
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libFreeImage.a" $1/lib/$TYPE/$PLATFORM/FreeImage.a
        cp Source/FreeImage.h $1/include
        secure $1/lib/$TYPE/$PLATFORM/FreeImage.a FreeImage.pkl
    elif [[ "$TYPE" =~ ^(linux)$ ]]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libFreeImage.a" $1/lib/$TYPE/$PLATFORM/FreeImage.a
        cp Source/FreeImage.h $1/include
        secure $1/lib/$TYPE/$PLATFORM/FreeImage.a FreeImage.pkl
    elif [ "$TYPE" == "vs" ]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE
        cp Source/FreeImage.h $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImage.lib
        cp -v "build_${TYPE}_${ARCH}/Debug/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImageD.lib
        secure $1/lib/$TYPE/$PLATFORM/FreeImage.lib FreeImage.pkl
    elif [ "$TYPE" == "android" ]; then
        cp Source/FreeImage.h $1/include
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
        cp -v build__${TYPE}_$ABI/Release/lib/libFreeImage.a $1/lib/$TYPE/$PLATFORM/libFreeImage.a
        secure $1/lib/$TYPE/$PLATFORM/libFreeImage.a FreeImage.pkl
    elif [ "$TYPE" == "emscripten" ]; then
        cp Source/FreeImage.h $1/include
        if [ -d $1/lib/$TYPE/$PLATFORM/ ]; then
            rm -r $1/lib/$TYPE/$PLATFORM/
        fi
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v build_${TYPE}/build/libFreeImage.a $1/lib/$TYPE/$PLATFORM/libfreeimage.a
        secure $1/lib/$TYPE/$PLATFORM/libfreeimage.a FreeImage.pkl
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v license-fi.txt $1/license/
    cp -v license-gplv2.txt $1/license/
    cp -v license-gplv3.txt $1/license/
}

# executed inside the lib src dir
function clean() {

    if [ "$TYPE" == "android" ]; then
        if [ -d "build__${TYPE}_${ABI}" ]; then
            rm -r build__${TYPE}_${ABI}
        fi
    elif [ "$TYPE" == "emscripten" ]; then
        if [ -d $1/lib/$TYPE/$PLATFORM/ ]; then
            rm -r $1/lib/$TYPE/$PLATFORM/
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    else
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
        # run dedicated clean script
        clean.sh
    fi
}


