#!/usr/bin/env bash
#
# libxml2
# XML parser
# http://xmlsoft.org/index.html
#
# uses an automake build system

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "tvos" "android" "emscripten")
# uses an automake build system # required for svg

FORMULA_DEPENDS=( "automake")


# define the version by sha
VER=2.10.4
URL=https://github.com/GNOME/libxml2/archive/refs/tags/v${VER}

ICU_VER=73-1
DEPEND_URL=https://github.com/unicode-org/icu/archive/refs/tags/release-${ICU_VER}

# download the source code and unpack it into LIB_NAME
function download() {

    if [ "$TYPE" == "vs" ] ; then
        DOWNLOAD_TYPE="zip"
    else 
        DOWNLOAD_TYPE="tar.gz"
    fi

    . "$DOWNLOADER_SCRIPT"
    downloader "${URL}.${DOWNLOAD_TYPE}"

    if [ "$TYPE" == "vs" ] ; then
       unzip  v${VER}.${DOWNLOAD_TYPE}
       rm v${VER}.${DOWNLOAD_TYPE}
    else 
       tar xzhf v${VER}.${DOWNLOAD_TYPE}
       rm v${VER}.${DOWNLOAD_TYPE}
    fi
    

    mv libxml2-${VER} libxml2
    

    downloader ${DEPEND_URL}
    tar xzhf release-${ICU_VER}.tar.gz
    mv icu-release-${ICU_VER} icu
    rm release-${ICU_VER}.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    if [ "$TYPE" == "android" ]; then
        cp -fr $FORMULA_DIR/glob.h .
    fi

}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "vs" ] ; then   

        if [ $ARCH == 32 ] ; then
            PLATFORM="Win32"
        elif [ $ARCH == 64 ] ; then
            PLATFORM="x64"
        elif [ $ARCH == "arm64" ] ; then
            PLATFORM="ARM64"
        elif [ $ARCH == "arm" ]; then
            PLATFORM="ARM"            
        else
            vs-build libxml2.vcxproj "Build /p:PlatformToolset=v142" "Release|x64"
        fi


        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"        

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"


        DEFS='-DCMAKE_C_STANDARD=17 \
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
            -DLIBXML2_WITH_SCHEMATRON=OFF'

        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release

        cd ..
            
    elif [ "$TYPE" == "android" ]; then
        ./autogen.sh
        cp $FORMULA_DIR/config.h .

        find . -name "test*.c" | xargs rm
        find . -name "run*.c" | xargs rm
        
        source ../../android_configure.sh $ABI cmake
        # mkdir -p cmake
        # cd cmake
        # # ln -s .. libxml2

        # cp -fr $FORMULA_DIR/CMakeLists.txt .
        # #wget https://raw.githubusercontent.com/martell/libxml2.cmake/master/CmakeLists.txt
        # perl -pi -e 's|^include_directories\("\$\{XML2_SOURCE_DIR\}/win32/VC10"\)|#include_directories\("\${XML2_SOURCE_DIR}/win32/VC10"\)|g' CMakeLists.txt
        # cd ..

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
        ./autogen.sh
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"

        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}


    elif [ "$TYPE" == "emscripten" ]; then
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
        ./autogen.sh
        emconfigure ./configure --without-lzma --without-zlib --disable-shared --without-ftp --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        emmake make clean
        emmake make -j${PARALLEL_MAKE}


    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "msys2" ]; then
        ./autogen.sh
        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" || [ "$TYPE" == "linuxaarch64" ]; then
        source ../../${TYPE}_configure.sh
        export CFLAGS="$CFLAGS -DTRIO_FPCLASSIFY=fpclassify"
        sed -i "s/#if defined.STANDALONE./#if 0/g" trionan.c

        find . -name "test*.c" | xargs rm
        find . -name "run*.c" | xargs rm
        
        ./autogen.sh
        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-icolincunv --without-legacy --without-modules --without-output --without-python --without-schematron --without-threads --host $HOST
        make clean
        #echo "int main(){ return 0; }" > xmllint.c
        #echo "int main(){ return 0; }" > xmlcatalog.c
        #echo "int main(){ return 0; }" > testSchemas.c
        #echo "int main(){ return 0; }" > testRelax.c
        #echo "int main(){ return 0; }" > testSAX.c
        #echo "int main(){ return 0; }" > testHTML.c
        #echo "int main(){ return 0; }" > testXPath.c
        #echo "int main(){ return 0; }" > testURI.c
        #echo "int main(){ return 0; }" > testThreads.c
        #echo "int main(){ return 0; }" > testC14N.c
        make -j${PARALLEL_MAKE}


    elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        find . -name "test*.c" | xargs rm
        find . -name "run*.c" | xargs rm

        ./autogen.sh
        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}

    elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        
        find . -name "test*.c" | xargs rm
        find . -name "run*.c" | xargs rm

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
    
    mkdir -p $1/lib/$TYPE
    cp -Rv include/libxml/* $1/include/libxml/

    if [ "$TYPE" == "vs" ] ; then
        if [ $ARCH == 32 ] ; then
            PLATFORM="Win32"
        elif [ $ARCH == 64 ] ; then
            PLATFORM="x64"
        elif [ $ARCH == "arm64" ] ; then
            PLATFORM="ARM64"
        elif [ $ARCH == "arm" ]; then
            PLATFORM="ARM"
        fi        
        
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/libxml2s.lib" $1/lib/$TYPE/$PLATFORM/libxml2.lib       

    elif [ "$TYPE" == "tvos" ]; then
        # copy lib
        cp -Rv ./build_${TYPE}/Release-appletvos/libxml2.a $1/lib/$TYPE/xml2.a
     elif [ "$TYPE" == "ios" ]; then
        # copy lib
        cp -Rv ./build_${TYPE}/Release-iphoneos/libxml2.a $1/lib/$TYPE/xml2.a
    elif [ "$TYPE" == "osx" ]; then
        # copy lib
        cp -Rv .libs/libxml2.a $1/lib/$TYPE/xml2.a
    elif [ "$TYPE" == "android" ] ; then
        mkdir -p $1/lib/$TYPE/$ABI
        # copy lib
        cp -Rv build_${TYPE}_${ABI}/libxml2.a $1/lib/$TYPE/$ABI/libxml2.a
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ]; then
        mkdir -p $1/lib/$TYPE
        # copy lib
        cp -Rv libxml2.a $1/lib/$TYPE/libxml2.a
    elif [ "$TYPE" == "emscripten" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
        mkdir -p $1/lib/$TYPE
        # copy lib
        cp -Rv .libs/libxml2.a $1/lib/$TYPE/libxml2.a
    fi

    # copy license file
    rm -rf $1/license # remove any older files if exists
    mkdir -p $1/license
    cp -v Copyright $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ] ; then
        rm -f *.lib
    else
        make clean
    fi
}
