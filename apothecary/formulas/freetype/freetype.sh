#!/usr/bin/env bash
#
# Free Type
# cross platform ttf/optf font loder
# http://freetype.org/
#
# an autotools project

FORMULA_TYPES=("osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "vs" "android" "emscripten" "linux" )
FORMULA_DEPENDS=("zlib" "libpng" "brotli")

# define the version
VER=2.13.3
BUILD_ID=1
DEFINES=""

GIT_VER="VER-${VER//./-}"

# tools for git use
GIT_TAG="VER-${VER%.*}"
GIT_HUB=https://github.com/freetype/freetype/tags
URL="https://github.com/freetype/freetype/archive/refs/tags/${GIT_VER}.tar.gz"
GIT_URL="https://github.com/freetype/freetype"

# download the source code and unpack it into LIB_NAME
function download() {
    echo "Downloading freetype-$GIT_VER"

    . "$DOWNLOADER_SCRIPT"
    downloader $URL

    tar -xzf $GIT_VER.tar.gz
    mv freetype-$GIT_VER freetype
    rm $GIT_VER*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    mkdir -p lib/$TYPE

    rm -f ./CMakeLists.txt
    cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "freetype" ${ARCH} ${VER} "$LIBS_DIR_REAL/freetype/lib/$TYPE/$PLATFORM" ${BUILD_ID})
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
        result=$(load "freetype2" | tail -n 1)
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


    DEFINES="	
		    -DCMAKE_C_STANDARD=${C_STANDARD} \
		    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include"
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"

        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlicommon.a"
        LIBBROTLI_ENC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlienc.a"
        LIBBROTLI_DEC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlidec.a"

        BROTLI="
			-DFT_REQUIRE_BROTLI=ON \
			-DFT_DISABLE_BROTLI=OFF"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM:${LIBBROTLI_ROOT}/lib/$TYPE/$PLATFORM"

        EXTRA_DEFS="
			${BROTLI} \
			-D FT_REQUIRE_ZLIB=ON \
        	-D FT_DISABLE_BZIP2=ON \
        	-D FT_REQUIRE_HARFBUZZ=OFF \
        	-D FT_DISABLE_HARFBUZZ=ON \
        	-D FT_DISABLE_PNG=OFF \
            -D FT_REQUIRE_PNG=ON \
			-DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DBROTLI_ROOT=${LIBBROTLI_ROOT} \
            -DBROTLIDEC_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLIDEC_LIBRARIES=${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
		    -DBUILD_SHARED_LIBS=OFF"

        cmake .. ${DEFINES} \
            ${EXTRA_DEFS} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INCLUDE_PATH="$LIBBROTLI_INCLUDE_DIR;$LIBPNG_INCLUDE_DIR;$ZLIB_INCLUDE_DIR" \
            -DCMAKE_LIBRARY_PATH="$LIBBROTLI_DEC_LIB:${LIBPNG_LIBRARY}:${ZLIB_LIBRARY}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fPIC -std=c${C_STANDARD} -fvisibility=hidden -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE} -I${ZLIB_INCLUDE_DIR} -I${LIBPNG_INCLUDE_DIR} -I${LIBBROTLI_INCLUDE_DIR}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fPIC -fvisibility=hidden -frtti ${FLAG_RELEASE} -I${ZLIB_INCLUDE_DIR} -I${LIBPNG_INCLUDE_DIR} -I${LIBBROTLI_INCLUDE_DIR}" \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_BUILD_TYPE=Release \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=ON \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "vs" ]; then

        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"

        grep '#elif defined( _M_ARM64 ) || defined( _M_ARM )' include/freetype/internal/ftcalc.h
        if [ $? -eq 0 ]; then
            sed -i 's/#elif defined( _M_ARM64 ) || defined( _M_ARM )/#elif defined( _M_ARM64 ) || defined( _M_ARM ) || defined( _M_ARM64EC )/g' include/freetype/internal/ftcalc.h
            echo "ARM64EC Patch applied successfully. 2.13.2 https://gitlab.freedesktop.org/freetype/freetype/-/merge_requests/334"
        else
            echo "ARM64EC Patch The line to be replaced was not found. 2.13.2 "
        fi

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib"

        LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"
        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM"
        LIBBROTLI_COMMON_LIB="$LIBBROTLI_LIBRARY/brotlicommon.lib"
        LIBBROTLI_ENC_LIB="$LIBBROTLI_LIBRARY/brotlienc.lib"
        LIBBROTLI_DEC_LIB="$LIBBROTLI_LIBRARY/brotlidec.lib"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH};${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM;${ZLIB_ROOT}/lib/$TYPE/$PLATFORM;${LIBBROTLI_ROOT}/lib/$TYPE/$PLATFORM"

        BROTLI="
			-DFT_REQUIRE_BROTLI=ON \
			-DFT_DISABLE_BROTLI=OFF"

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.lib *.o
        if [ "$PLATFORM" == "ARM64EC" ]; then
            BROTLI="
			-DFT_REQUIRE_BROTLI=OFF \
			-DFT_DISABLE_BROTLI=ON"
        fi
        EXTRA_DEFS="
            ${BROTLI} \
            -D FT_REQUIRE_ZLIB=ON \
        	-D FT_DISABLE_BZIP2=ON \
        	-D FT_REQUIRE_HARFBUZZ=OFF \
        	-D FT_DISABLE_HARFBUZZ=ON \
        	-D FT_DISABLE_PNG=OFF \
            -D FT_REQUIRE_PNG=ON \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG=bin"
        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}"
        cmake .. ${DEFINES} \
            ${EXTRA_DEFS} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -D BUILD_SHARED_LIBS=OFF \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS} " \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DBROTLI_ROOT=${LIBBROTLI_ROOT} \
            -DCMAKE_INCLUDE_PATH="$LIBBROTLI_INCLUDE_DIR;$LIBPNG_INCLUDE_DIR;$ZLIB_INCLUDE_DIR" \
            -DCMAKE_LIBRARY_PATH="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB};${LIBPNG_LIBRARY};${ZLIB_LIBRARY}" \
            -DBROTLIDEC_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLIDEC_LIBRARIES="${LIBBROTLI_LIBRARY};${LIBBROTLI_ENC_LIB};${LIBBROTLI_DEC_LIB}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}"
        cmake .. ${DEFINES} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -D BUILD_SHARED_LIBS=OFF \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DBROTLI_ROOT=${LIBBROTLI_ROOT} \
            -DCMAKE_INCLUDE_PATH="$LIBBROTLI_INCLUDE_DIR;$LIBPNG_INCLUDE_DIR;$ZLIB_INCLUDE_DIR" \
            -DCMAKE_LIBRARY_PATH="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB};${LIBPNG_LIBRARY};${ZLIB_LIBRARY}" \
            -DBROTLIDEC_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLIDEC_LIBRARIES="${LIBBROTLI_LIBRARY};${LIBBROTLI_ENC_LIB};${LIBBROTLI_DEC_LIB}"
        cmake --build . --config Debug -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "msys2" ]; then
        # configure with arch
        if [ $ARCH == 32 ]; then
            ./configure CFLAGS="-arch i386" --without-bzip2 --without-brotli --with-harfbuzz=no
        elif [ $ARCH == 64 ]; then
            ./configure CFLAGS="-arch x86_64" --without-bzip2 --without-brotli --with-harfbuzz=no
        fi

        make clean
        make -j${PARALLEL_MAKE}

    elif [ "$TYPE" == "msys2" ]; then
        mkdir -p build_$TYPE
        cd build_$TYPE
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            ${DEFINES} \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -D FT_REQUIRE_ZLIB=ON \
            -D FT_DISABLE_BZIP2=ON \
            -D FT_REQUIRE_HARFBUZZ=OFF \
            -D FT_DISABLE_HARFBUZZ=ON \
            -D FT_DISABLE_PNG=OFF \
            -D FT_REQUIRE_PNG=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [ "$TYPE" == "linux" ]; then

        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh $ABI
        fi

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="${LIBS_ROOT}/libpng/"
        LIBPNG_INCLUDE_DIR="${LIBS_ROOT}/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/${TYPE}/${PLATFORM}/libpng16.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            ${DEFINES} \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -D FT_REQUIRE_ZLIB=ON \
            -D FT_DISABLE_BZIP2=ON \
            -D FT_REQUIRE_HARFBUZZ=OFF \
            -D FT_DISABLE_HARFBUZZ=ON \
            -D FT_DISABLE_PNG=OFF \
            -D FT_REQUIRE_PNG=ON \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++${CPP_STANDARD} -frtti ${FLAG_RELEASE} -I${ZLIB_INCLUDE_DIR} -I${LIBPNG_INCLUDE_DIR}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c${C_STANDARD} -Wno-implicit-function-declaration ${FLAG_RELEASE} -I${ZLIB_INCLUDE_DIR} -I${LIBPNG_INCLUDE_DIR}" \
            -DCMAKE_INCLUDE_PATH="${LIBPNG_INCLUDE_DIR}:${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBPNG_LIBRARY}:${ZLIB_LIBRARY}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include
            cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..
    elif [ "$TYPE" == "android" ]; then

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="${LIBS_ROOT}/libpng/"
        LIBPNG_INCLUDE_DIR="${LIBS_ROOT}/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/${TYPE}/${PLATFORM}/libpng16.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake
        rm -rf "build_${ABI}/"
        rm -rf "build_${ABI}/CMakeCache.txt"
        mkdir -p "build_$ABI"
        cd "./build_$ABI"
        NO_LINK_BROTLI=OFF
        if [ "$PLATFORM" == "ARM64" ]; then
            NO_LINK_BROTLI=ON
        fi

        EXTRA_DEFS="
            -DFT_DISABLE_BROTLI=${NO_LINK_BROTLI} 
            "
        cmake .. ${DEFINES} \
            ${EXTRA_DEFS} \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_PATH="${LIBPNG_INCLUDE_DIR}:${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBPNG_LIBRARY}:${ZLIB_LIBRARY}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DFT_REQUIRE_ZLIB=ON \
            -DFT_DISABLE_BZIP2=ON \
            -DFT_REQUIRE_HARFBUZZ=OFF \
            -DFT_DISABLE_HARFBUZZ=ON \
            -DFT_DISABLE_PNG=OFF \
            -DFT_REQUIRE_PNG=ON \
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
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
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

    elif [ "$TYPE" == "emscripten" ]; then

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="${LIBS_ROOT}/libpng/"
        LIBPNG_INCLUDE_DIR="${LIBS_ROOT}/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/${TYPE}/${PLATFORM}/libpng16.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        pkg-config --modversion libpng

        BROTLI="
			-DFT_REQUIRE_BROTLI=OFF \
			-DFT_DISABLE_BROTLI=ON"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.a
        export PATH="${PATH}:${LIBPNG_INCLUDE_DIR}"
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            ${DEFINES} \
            ${BROTLI} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_LIBRARIES=${LIBPNG_LIBRARY} \
            -DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_C_FLAGS=" -fPIC -std=c${C_STANDARD} -fvisibility=hidden -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE} -I${ZLIB_INCLUDE_DIR} -I${LIBPNG_INCLUDE_DIR}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -D FT_REQUIRE_ZLIB=ON \
            -D FT_DISABLE_BZIP2=ON \
            -D FT_REQUIRE_HARFBUZZ=OFF \
            -D FT_DISABLE_HARFBUZZ=ON \
            -D FT_DISABLE_PNG=OFF \
            -D FT_REQUIRE_PNG=ON \
            -DCMAKE_INCLUDE_PATH="${LIBPNG_INCLUDE_DIR}:${ZLIB_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBPNG_LIBRARY}:${ZLIB_LIBRARY}" \
            -DBUILD_SHARED_LIBS=OFF \
            -B . \
            -G 'Unix Makefiles'

        # cat CMakeCache.txt
        # cat Makefile

        $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        $EMSDK/upstream/emscripten/emmake make install

        # cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    #remove old include files if they exist
    if [ -d "$1/include" ]; then
        rm -rf $1/include
    fi

    # copy headers
    mkdir -p $1/include/freetype/

    # copy files from the build root
    cp -R include/* $1/include/

    mkdir -p $1/lib/$TYPE
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/freetype2/" $1/include
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libfreetype.a" $1/lib/$TYPE/$PLATFORM/libfreetype.a
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.a" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/include/" $1/
        cp -v "build_${TYPE}_${ARCH}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.lib" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        # cp -v "build_${TYPE}_${ARCH}/lib/"*.pdb $1/lib/$TYPE/$PLATFORM/
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/freetype2/" $1/include
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libfreetype.a" $1/lib/$TYPE/$PLATFORM/libfreetype.a
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/freetype2.pc" $1/lib/${TYPE}/${PLATFORM}/freetype.pc
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.a" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/freetype.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    elif [ "$TYPE" == "linux" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/freetype2/" $1/include
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libfreetype.a" $1/lib/$TYPE/$PLATFORM/libfreetype.a
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.a" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/freetype2.pc" $1/lib/${TYPE}/${PLATFORM}/freetype.pc
        PKG_FILE="$1/lib/$TYPE/$PLATFORM/freetype.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
    elif [ "$TYPE" == "msys2" ]; then
        # cp -v lib/$TYPE/libfreetype.a $1/lib/$TYPE/libfreetype.a
        echoWarning "TODO: copy msys2 lib"
    elif [ "$TYPE" == "android" ]; then
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
        cp -v build_$ABI/libfreetype.a $1/lib/$TYPE/$PLATFORM/libfreetype.a
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.a" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/libfreetype.a" $1/lib/$TYPE/$PLATFORM/libfreetype.a
        . "$SECURE_SCRIPT"
        secure "$1/lib/$TYPE/$PLATFORM/libfreetype.a" "freetype.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -v "build_${TYPE}_$PLATFORM/freetype2.pc" $1/lib/$TYPE/$PLATFORM/freetype.pc
        PKG_FILE="$1/lib/$TYPE/$PLATFORM/freetype.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"
        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE.TXT $1/license/LICENSE
    cp -v docs/FTL.TXT $1/license/
    cp -v docs/GPLv2.TXT $1/license/
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
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "emscripten" ]; then
        if [ -d "build_${TYPE}" ]; then
            rm -r build_${TYPE}
        fi
    else
        rm -f CMakeCache.txt *.a *.o *.lib
        make clean
    fi
}


