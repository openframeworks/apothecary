#!/usr/bin/env bash
#
# libxml2
# XML parser
# http://xmlsoft.org/index.html
#
# uses an automake build system

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" )
# uses an automake build system # required for svg

FORMULA_DEPENDS=( "zlib" )


# define the version by sha
VER=2.12.5
URL=https://github.com/GNOME/libxml2/archive/refs/tags/v${VER}

GIT_URL=https://github.com/GNOME/libxml2.git


ICU_VER=74-2
ICU_VER_U=74_2

DEPEND_URL=https://github.com/unicode-org/icu/releases/download/release-${ICU_VER}/icu4c-${ICU_VER_U}-src


# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"

    if [ "$TYPE" == "vs" ]; then  # fix for tar symbol link privildge errors 
        DOWNLOAD_TYPE="zip"
        git clone $GIT_URL
        cd libxml2
        git checkout -b v${VER} tags/v${VER}
        cd ../

        if [ ! -d "icu" ] ; then                  
            downloader "${DEPEND_URL}.${DOWNLOAD_TYPE}"
            unzip -qq "icu4c-${ICU_VER_U}-src.${DOWNLOAD_TYPE}"
            rm -f "icu4c-${ICU_VER_U}-src.${DOWNLOAD_TYPE}"
        fi
    else

        git clone $GIT_URL
        cd libxml2
        git checkout -b v${VER} tags/v${VER}
        cd ../
        if [ ! -d "icu" ] ; then    
            downloader "${DEPEND_URL}.zip"
            unzip -qq "icu4c-${ICU_VER_U}-src.zip"
            rm -f "icu4c-${ICU_VER_U}-src.zip"
        fi

    fi
       

    
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    if [ "$TYPE" == "android" ]; then
        cp -fr $FORMULA_DIR/glob.h .
    fi

    apothecaryDependencies download
    
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib

    rm -f ./CMakeLists.txt
    cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt

}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)
    DEFS="  -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include\
            -DLIBXML2_WITH_UNICODE=ON \
            -DLIBXML2_WITH_LZMA=OFF \
            -DLIBXML2_WITH_ZLIB=ON \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=ON \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_UNICODE=ON \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_DOC=OFF \
            -DLIBXML2_WITH_SCHEMATRON=OFF"

    if [ "$TYPE" == "vs" ] ; then 
        echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoVerbose "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        EXTRA_DEFS="-DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"         
        cmake .. ${DEFS} \
            ${EXTRA_DEFS} \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_PREFIX_PATH="${ZLIB_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release --target install
        cd ..
            
    elif [ "$TYPE" == "android" ]; then
        ./autogen.sh
        cp $FORMULA_DIR/config.h .

        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm
        
        source ../../android_configure.sh $ABI cmake

        mkdir -p build_${TYPE}_${ABI}
        cd build_${TYPE}_${ABI}
        
        export CMAKE_CFLAGS="$CFLAGS"
        export CFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
        export LDFLAGS=""
        cmake .. -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI=$ABI \
            .. ${DEFS} \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_TOOLCHAIN=clang++ \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++17 -Wno-implicit-function-declaration -frtti " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c17 -Wno-implicit-function-declaration -frtti " \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
        cmake --build . --config Release
        cd ..
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        mkdir -p "build_${TYPE}_$PLATFORM"
        cd "build_${TYPE}_$PLATFORM"
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
             ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DZLIB_ROOT="$LIBS_ROOT/zlib/" \
            -DZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include" \
            -DZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a" 
        cmake --build . --config Release --target install
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm
        . "$DOWNLOADER_SCRIPT"
        downloader "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
        downloader "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
        export CFLAGS="-pthread"
        export CXXFLAGS="-pthread"
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/zlib.wasm"
        mkdir -p build_$TYPE
        cd build_$TYPE
        rm -f CMakeCache.txt *.a *.o *.wasm
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_C_STANDARD=17 \
            -B . \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DLIBXML2_WITH_ZLIB=OFF \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++17 -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c17 -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}"
        cmake --build . --config Release 
        cd ..
    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "msys2" ]; then
            #./autogen.sh
            find . -name "test*.c" | xargs -r rm
            find . -name "run*.c" | xargs -r rm
            mkdir -p build_$TYPE
            cd build_$TYPE
            rm -f CMakeCache.txt *.a *.o
            cmake .. \
                ${DEFS} \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_C_STANDARD=17 \
                -DCMAKE_CXX_STANDARD=17 \
                -DCMAKE_CXX_STANDARD_REQUIRED=ON \
                -DCMAKE_CXX_EXTENSIONS=OFF \
                -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
                -DCMAKE_INSTALL_INCLUDEDIR=include \
                -DCMAKE_SYSTEM_NAME=$TYPE \
                -DCMAKE_SYSTEM_PROCESSOR=$ABI
                
            cmake --build . --config Release
            cd ..
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "linuxaarch64" ]; then
        source ../../${TYPE}_configure.sh
        export CFLAGS="$CFLAGS -DTRIO_FPCLASSIFY=fpclassify"
        sed -i "s/#if defined.STANDALONE./#if 0/g" trionan.c
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm
        rm -f *.o
        mkdir -p build_$TYPE
        cd build_$TYPE
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            ${DEFS} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_SYSTEM_NAME=$TYPE \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DLIBXML2_WITH_LZMA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/aarch64-linux-gnu.toolchain.cmake \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF
        cmake --build . --config Release
        cd ..
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # prepare headers directory if needed
    mkdir -p $1/include/libxml
    
    # create a common lib directory path
    mkdir -p $1/lib/$TYPE

    # copy files specific to each build TYPE
    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        mkdir -p $1/include/libxml
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libxml2/"* $1/include/
        cp -v "build_${TYPE}_${PLATFORM}/Release/libxml2.lib" $1/lib/$TYPE/$PLATFORM/libxml2.lib
        cp -v "build_${TYPE}_${PLATFORM}/Release/libxml2.dll" $1/lib/$TYPE/$PLATFORM/libxml2.dll     
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/$PLATFORM/libxml2.lib
    elif [ "$TYPE" == "android" ] ; then
        mkdir -p $1/lib/$TYPE/$ABI
        cp -Rv include/libxml/* $1/include/libxml/
        cp -Rv build_${TYPE}_${ABI}/libxml2.a $1/lib/$TYPE/$ABI/libxml2.a
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/libxml2.a
        cp -Rv build_${TYPE}_${ABI}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [ "$TYPE" == "emscripten" ]; then
        cp -Rv include/libxml/* $1/include/libxml/
        cp -v "build_${TYPE}/xml2_wasm.wasm" $1/lib/$TYPE/libxml2.wasm
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/libxml2.wasm
        cp -Rv build_${TYPE}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/include/libxml
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libxml2.a" $1/lib/$TYPE/$PLATFORM/libxml2.a
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/libxml2.a
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libxml2/libxml/" $1/include/libxml
        cp -Rv build_${TYPE}_${PLATFORM}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linux" ] || [ "$TYPE" == "linuxaarch64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
        cp -v "build_${TYPE}/libxml2.a" $1/lib/$TYPE/libxml2.a
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/libxml2.a
        cp -Rv build_${TYPE}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
        cp -Rv include/libxml/* $1/include/libxml/
    else
        echo "Unknown build TYPE: $TYPE"
        exit 1
    fi

    # copy license file
    if [ -d "$1/license" ]; then
        rm -r $1/license
    fi
    mkdir -p $1/license
    cp -v Copyright $1/license/
}


# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ] ; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
    elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ] || [ "$TYPE" == "xros" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
    else
        make clean
    fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "libxml2" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    echo "load file ${SAVE_FILE}"

    if loadsave ${TYPE} "libxml2" ${ARCH} ${VER} "${SAVE_FILE}"; then
      echo "The entry exists and doesn't need to be rebuilt."
      return 0;
    else
      echo "The entry doesn't exist or needs to be rebuilt."
      return 1;
    fi
}

