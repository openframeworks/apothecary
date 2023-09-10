#!/usr/bin/env bash
#
# libxml2
# XML parser
# http://xmlsoft.org/index.html
#
# uses an automake build system

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "tvos" "android" "emscripten")
# uses an automake build system # required for svg

FORMULA_DEPENDS=( "zlib" )


# define the version by sha
VER=2.11.4
URL=https://github.com/GNOME/libxml2/archive/refs/tags/v${VER}

GIT_URL=https://github.com/GNOME/libxml2.git


ICU_VER=73-2
ICU_VER_U=73_2

DEPEND_URL=https://github.com/unicode-org/icu/releases/download/release-${ICU_VER}/icu4c-${ICU_VER_U}-src


# download the source code and unpack it into LIB_NAME
function download() {

    if [ "$TYPE" == "vs" ]; then  # fix for tar symbol link privildge errors 
        DOWNLOAD_TYPE="zip"
        . "$DOWNLOADER_SCRIPT"
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
            wget -q "${DEPEND_URL}.zip"
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

    

}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "vs" ] ; then 
        echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoVerbose "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        cmake .. \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DLIBXML2_WITH_UNICODE=ON \
            -DLIBXML2_WITH_LZMA=OFF \
            -DLIBXML2_WITH_ZLIB=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=OFF \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML_THREAD_ENABLED=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_DOCB=OFF \
            -DLIBXML2_WITH_SCHEMATRON=OFF
        cmake --build . --config Release

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
            -DANDROID_TOOLCHAIN=clang++ \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++17 -Wno-implicit-function-declaration -frtti " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c17 -Wno-implicit-function-declaration -frtti " \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DLIBXML2_WITH_LZMA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=OFF \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML_THREAD_ENABLED=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF \
            -G 'Unix Makefiles' 

        make -j${PARALLEL_MAKE} VERBOSE=1
        cd ..
    elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        mkdir -p build_$TYPE
        cd build_$TYPE
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DLIBXML2_WITH_LZMA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DLIBXML2_WITH_ZLIB=OFF \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=OFF \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML_THREAD_ENABLED=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF
        cmake --build . --config Release
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm
        . "$DOWNLOADER_SCRIPT"

        downloader "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
        downloader "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
        
        export CFLAGS="-pthread"
        export CXXFLAGS="-pthread"
        export CMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
        echo "$CMAKE_TOOLCHAIN_FILE"

        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        LIBS_ROOT=$(realpath $LIBS_DIR)

        CAIRO_HAS_PNG_FUNCTIONS=1

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/zlib.a"
        mkdir -p build_$TYPE
        cd build_$TYPE
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B build \
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
            -DNO_BUILD_LIBRAWLITE=ON \
            -DNO_BUILD_OPENEXR=ON \
            -DNO_BUILD_WEBP=ON \
            -DNO_BUILD_JXR=ON \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DLIBXML2_WITH_LZMA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=OFF \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML_THREAD_ENABLED=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build build --config Release
        cd ..
    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "msys2" ]; then
            #./autogen.sh
            find . -name "test*.c" | xargs -r rm
            find . -name "run*.c" | xargs -r rm
            mkdir -p build_$TYPE
            cd build_$TYPE
            cmake .. \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_C_STANDARD=17 \
                -DCMAKE_CXX_STANDARD=17 \
                -DCMAKE_CXX_STANDARD_REQUIRED=ON \
                -DCMAKE_CXX_EXTENSIONS=OFF \
                -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
                -DCMAKE_INSTALL_INCLUDEDIR=include \
                -DLIBXML2_WITH_ZLIB=OFF \
                -DLIBXML2_WITH_LZMA=OFF \
                -DBUILD_SHARED_LIBS=OFF \
                -DLIBXML2_WITH_FTP=OFF \
                -DLIBXML2_WITH_HTTP=OFF \
                -DLIBXML2_WITH_HTML=OFF \
                -DLIBXML2_WITH_ICONV=OFF \
                -DLIBXML2_WITH_LEGACY=OFF \
                -DLIBXML2_WITH_MODULES=OFF \
                -DLIBXML_THREAD_ENABLED=OFF \
                -DLIBXML2_WITH_OUTPUT=ON \
                -DLIBXML2_WITH_PYTHON=OFF \
                -DLIBXML2_WITH_DEBUG=OFF \
                -DLIBXML2_WITH_THREADS=ON \
                -DLIBXML2_WITH_PROGRAMS=OFF \
                -DLIBXML2_WITH_TESTS=OFF \
                -DLIBXML2_WITH_THREAD_ALLOC=OFF
            cmake --build . --config Release
            cd ..
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "linuxaarch64" ]; then
        source ../../${TYPE}_configure.sh
        export CFLAGS="$CFLAGS -DTRIO_FPCLASSIFY=fpclassify"
        sed -i "s/#if defined.STANDALONE./#if 0/g" trionan.c

        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm
        mkdir -p build_$TYPE
        cd build_$TYPE
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DLIBXML2_WITH_LZMA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DLIBXML2_WITH_ZLIB=OFF \
            -DLIBXML2_WITH_FTP=OFF \
            -DLIBXML2_WITH_HTTP=OFF \
            -DLIBXML2_WITH_HTML=OFF \
            -DLIBXML2_WITH_ICONV=OFF \
            -DLIBXML2_WITH_LEGACY=OFF \
            -DLIBXML2_WITH_MODULES=OFF \
            -DLIBXML_THREAD_ENABLED=OFF \
            -DLIBXML2_WITH_OUTPUT=ON \
            -DLIBXML2_WITH_PYTHON=OFF \
            -DLIBXML2_WITH_DEBUG=OFF \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_PROGRAMS=OFF \
            -DLIBXML2_WITH_TESTS=OFF \
            -DLIBXML2_WITH_THREAD_ALLOC=OFF
        cmake --build . --config Release
        cd ..
    elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        
        find . -name "test*.c" | xargs -r rm
        find . -name "run*.c" | xargs -r rm

        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
        fi

        for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
            source ../../ios_configure.sh $TYPE $IOS_ARCH
            local PREFIX=$PWD/build/$TYPE/$IOS_ARCH
            ./autogen --prefix=$PREFIX  --host=$HOST --target=$HOST  --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
            ./configure --prefix=$PREFIX  --host=$HOST --target=$HOST  --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
            make clean
            make -j${PARALLEL_MAKE}
            make install
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "$TYPE" == "ios" ]; then
            lipo -create build/$TYPE/x86_64/lib/libxml2.a \
                         build/$TYPE/armv7/lib/libxml2.a \
                         build/$TYPE/arm64/lib/libxml2.a \
                        -output build/$TYPE/lib/libxml2.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create build/$TYPE/x86_64/lib/libxml2.a \
                         build/$TYPE/arm64/lib/libxml2.a \
                        -output build/$TYPE/lib/libxml2.a
        fi
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # prepare headers directory if needed
    mkdir -p $1/include/libxml
    
    # copy common headers
    cp -Rv include/libxml/* $1/include/libxml/

    # create a common lib directory path
    mkdir -p $1/lib/$TYPE

    # copy files specific to each build TYPE
    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/libxml2s.lib" $1/lib/$TYPE/$PLATFORM/libxml2.lib
        cp -Rv build_${TYPE}_${ARCH}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI
        cp -Rv build_${TYPE}_${ABI}/libxml2.a $1/lib/$TYPE/$ABI/libxml2.a
        cp -Rv build_${TYPE}_${ABI}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [ "$TYPE" == "emscripten" ]; then
        cp -v "build_${TYPE}/Release/libxml2s.a" $1/lib/$TYPE/libxml2.a
        cp -Rv build_${TYPE}/libxml/xmlversion.h $1/include/libxml/xmlversion.h
    elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        cp -Rv ./build_${TYPE}/$(platform_name)/libxml2.a $1/lib/$TYPE/xml2.a
    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxaarch64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
        cp -v "build_${TYPE}/lib/libxml2.a" $1/lib/$TYPE/libxml2.a
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
        rm -f *.lib
        rm -f *.o
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

