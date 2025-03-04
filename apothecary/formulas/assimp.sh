#! /bin/bash
#
# Open Asset Import Library
# cross platform 3D model loader
# https://github.com/assimp/assimp
#
# uses CMake

FORMULA_TYPES=("osx" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" "vs")
FORMULA_DEPENDS=("zlib")

# define the version
VER=5.4.3
BUILD_ID=2
DEFINES=""

# tools for git use
GIT_URL=https://github.com/assimp/assimp
GIT_TAG=

DEFAULT_VS_STATIC=1

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    echo "Downloading Assimp $VER"
    # stable release from GitHub
    # echo "From $GIT_URL/archive/refs/tags/v$VER.zip"
    # curl -LO "$GIT_URL/archive/refs/tags/v$VER.zip"

    # unzip -oq "v$VER.zip"
    # mv "assimp-$VER" assimp
    # rm "v$VER.zip"


    if [ "$TYPE" == "vs" ]; then
        downloader "$GIT_URL/archive/refs/tags/v$VER.zip"
        unzip -oq v${VER}.zip
        mv assimp-$VER assimp
        rm v${VER}.zip
    else
        downloader "${GIT_URL}/archive/refs/tags/v$VER.tar.gz"
        tar -xf v${VER}.tar.gz
        mv assimp-${VER} assimp
        rm -f v${VER}.tar.gz
    fi

}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "Prepare"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "assimp" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
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
        echo "building $TYPE | $ARCH $PLATFORM"
        echo "--------------------"
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt || true
        find ./ -name "*.o" -type f -delete
        DEFINES="
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0
            -DASSIMP_BUILD_ZLIB=OFF 
            -DASSIMP_WARNINGS_AS_ERRORS=OFF"

        if [ "${ASSIMP_DOUBLE:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_DOUBLE_PRECISION=ON"
        fi
        if [ "${ASSIMP_NO_EXPORT:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_NO_EXPORT=ON"
        fi

        cmake .. ${DEFINES} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}

        cmake --build . --config Release -j${PARALLEL_MAKE}
        cd ..
        rm -f CMakeCache.txt

    elif [ "$TYPE" == "vs" ]; then

        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/${PLATFORM}/zlib.lib"

        DEFINES="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DASSIMP_BUILD_TESTS=0 \
            -DASSIMP_BUILD_SAMPLES=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DASSIMP_WARNINGS_AS_ERRORS=OFF"

        if [ "${ASSIMP_DOUBLE:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_DOUBLE_PRECISION=ON"
        fi
        if [ "${ASSIMP_NO_EXPORT:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_NO_EXPORT=ON"
        fi

        if [ "${ASSIMP_STATIC:-${DEFAULT_VS_STATIC}}" = "1" ]; then
            DEFINES="${DEFINES} \
            ${MT_TYPE_DEFINES} \
            -DBUILD_SHARED_LIBS=OFF"
            if [ $MULTITHREADED_TYPE == "MD" ]; then
                sed -i 's/\/MT/\/MD/g; s/\/MTd/\/MDd/g' CMakeLists.txt
            fi
        else
            DEFINES="${DEFINES} \
            ${MT_TYPE_DEFINES} \
            -DBUILD_SHARED_LIBS=ON"
        fi

        mkdir -p "build_${TYPE}_${PLATFORM}_debug"
        cd "build_${TYPE}_${PLATFORM}_debug"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true        

        cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
            cmake --build . --config Debug -j${PARALLEL_MAKE}
            rm -f CMakeCache.txt || true

        cd ..
        mkdir -p "build_${TYPE}_${PLATFORM}_release"
        cd "build_${TYPE}_${PLATFORM}_release"
         find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true 

        cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build . --config Release -j${PARALLEL_MAKE}

        cd ..
        echo "--------------------"
        echo "Completed Assimp for $TYPE | $ARCH | $VS_VER"

    elif [ "$TYPE" == "msys2" ]; then
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$ARCH/zlib.a"

        DEFINES="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DASSIMP_BUILD_TESTS=OFF \
            -DASSIMP_BUILD_SAMPLES=OFF \
            -DASSIMP_BUILD_3MF_IMPORTER=OFF \
            -DASSIMP_WARNINGS_AS_ERRORS=OFF \
            -DASSIMP_BUILD_ZLIB=OFF"

        if [ "${ASSIMP_DOUBLE:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_DOUBLE_PRECISION=ON"
        fi
        if [ "${ASSIMP_NO_EXPORT:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_NO_EXPORT=ON"
        fi

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt *.a *.o || true

        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_C_FLAGS="-fPIC -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE} -Wno-implicit-function-declaration" \
            -DCMAKE_CXX_FLAGS="-fPIC -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

    elif [ "$TYPE" == "android" ]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$ABI/zlib.a"

        DEFINES="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DASSIMP_BUILD_TESTS=OFF \
            -DASSIMP_BUILD_SAMPLES=OFF \
            -DASSIMP_BUILD_3MF_IMPORTER=OFF \
            -DASSIMP_WARNINGS_AS_ERRORS=OFF \
            -DASSIMP_ANDROID_JNIIOSYSTEM=ON \
            -DASSIMP_BUILD_DOCS=OFF \
            -DASSIMP_BUILD_STL_IMPORTER=0 \
            -DASSIMP_BUILD_BLEND_IMPORTER=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1 \
            -D_LARGEFILE64_SOURCE=1 \
            -DASSIMP_BUILD_ZLIB=OFF"

        if [ "${ASSIMP_DOUBLE:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_DOUBLE_PRECISION=ON"
        fi
        if [ "${ASSIMP_NO_EXPORT:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_NO_EXPORT=ON"
        fi

        mkdir -p "build_${TYPE}_${ABI}"
        cd "build_${TYPE}_${ABI}"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt *.a *.o

        cmake .. ${DEFINES} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_LIBRARIES=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "emscripten" ]; then

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        DEFINES="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"

        if [ "${ASSIMP_DOUBLE:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_DOUBLE_PRECISION=ON"
        fi
        if [ "${ASSIMP_NO_EXPORT:-0}" == "1" ]; then
            DEFINES="$DEFINES -DASSIMP_NO_EXPORT=ON"
        fi

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"
        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt *.a *.o *.a *.js
        rm -f CMakeCache.txt || true
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B . \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            ${DEFINES} \
            -DCMAKE_C_FLAGS="-DNDEBUG -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE} -Wno-nontrivial-memaccess" \
            -DCMAKE_CXX_FLAGS="-DNDEBUG -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE} -Wno-nontrivial-memaccess" \
            -DLINK_FLAGS="${LINK_FLAGS}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DASSIMP_BUILD_STL_IMPORTER=0 \
            -DASSIMP_BUILD_BLEND_IMPORTER=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DENABLE_VISIBILITY=ON \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
            # -G 'Unix Makefiles'
        # $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        # $EMSDK/upstream/emscripten/emmake make install
        cmake --build . --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [[ "$TYPE" =~ ^(linux)$ ]]; then

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        DEFINES="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"

        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.o *.a

        cmake .. \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_CXX_FLAGS="-fPIC ${FLAG_RELEASE}" \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_C_FLAGS="-fPIC ${FLAG_RELEASE}" \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib \
            $DEFINES
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -p $1/include
    rm -rf $1/include/assimp
    rm -rf $1/include/*
    cp -Rv include/* $1/include

    . "$SECURE_SCRIPT"
    # libs
    mkdir -p $1/lib/$TYPE
    if [ "$TYPE" == "vs" ]; then
        cp -v -r build_${TYPE}_${PLATFORM}_release/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/Release
        mkdir -p $1/lib/$TYPE/$PLATFORM/Debug
        if [ "${ASSIMP_STATIC:-${DEFAULT_VS_STATIC}}" = "1" ]; then
            cp -v "build_${TYPE}_${PLATFORM}_release/lib/Release/assimp-vc${VC_VERSION}-mt.lib" $1/lib/$TYPE/$PLATFORM/libassimp.lib
            cp -v "build_${TYPE}_${PLATFORM}_debug/lib/Debug/assimp-vc${VC_VERSION}-mtd.lib" $1/lib/$TYPE/$PLATFORM/libassimpD.lib
            secure "$1/lib/$TYPE/$PLATFORM/libassimp.lib" "assimp.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        else
            cp -v "build_${TYPE}_${PLATFORM}_release/bin/Release/assimp-vc${VC_VERSION}-mt.dll" $1/lib/$TYPE/$PLATFORM/Release/assimp-vc${VC_VERSION}-mt.dll
            cp -v "build_${TYPE}_${PLATFORM}_debug/bin/Debug/assimp-vc${VC_VERSION}-mtd.dll" $1/lib/$TYPE/$PLATFORM/Debug/assimp-vc${VC_VERSION}-mtd.dll
            cp -v "build_${TYPE}_${PLATFORM}_debug/lib/Debug/assimp-vc${VC_VERSION}-mtd.lib" $1/lib/$TYPE/$PLATFORM/Debug/libassimpD.lib
            cp -v "build_${TYPE}_${PLATFORM}_release/lib/Release/assimp-vc${VC_VERSION}-mt.lib" $1/lib/$TYPE/$PLATFORM/Release/libassimp.lib
            secure "$1/lib/$TYPE/$PLATFORM/libassimp.lib" "assimp.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux|msys2)$ ]]; then
        cp -v -r build_${TYPE}_${PLATFORM}/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${PLATFORM}/lib/libassimp.a $1/lib/$TYPE/$PLATFORM/assimp.a
        secure "$1/lib/$TYPE/$PLATFORM/libassimp.a" "assimp.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -Rv build_${TYPE}_${ABI}/include/* $1/include
        cp -Rv build_${TYPE}_${ABI}/lib/libassimp.a $1/lib/$TYPE/$ABI/libassimp.a
        secure "$1/lib/$TYPE/$PLATFORM/libassimp.a" "assimp.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/lib/${TYPE}/${PLATFORM}
        cp -Rv build_${TYPE}_${PLATFORM}/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/lib/libassimp.a" $1/lib/$TYPE/${PLATFORM}/libassimp.a
        secure "$1/lib/$TYPE/$PLATFORM/libassimp.a" "assimp.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {

    if [ "$TYPE" == "vs" ]; then
        rm -f build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt
        echo "Assimp VS | $TYPE | $ARCH cleaned"

    elif [ "$TYPE" == "android" ]; then
        if [ -d "build" ]; then
            cd "build_${TYPE}_${ABI}"
            make clean
            cd ..
        fi
        rm -f CMakeCache.txt 2>/dev/null

    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux|msys2)$ ]]; then
        rm -f build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt
    else
        make clean
        make rebuild_cache
        rm -f CMakeCache.txt 2>/dev/null
    fi
}


