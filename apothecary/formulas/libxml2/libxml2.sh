#!/usr/bin/env bash
#
# libxml2
# XML parser
# http://xmlsoft.org/index.html
#
# uses an automake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "emscripten" "linux64" "linuxarmv6l" "linuxarmv7l" "android" )


# define the version by sha
VER=2.9.12

# download the source code and unpack it into LIB_NAME
function download() {
    wget -v http://xmlsoft.org/sources/libxml2-${VER}.tar.gz
    tar xzf libxml2-${VER}.tar.gz
    mv libxml2-${VER} libxml2
    rm libxml2-${VER}.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    if [ "$TYPE" == "android" ]; then
        cp -fr $FORMULA_DIR/glob.h .
    fi

    if [ "$TYPE" == "vs" ]; then
        cp -fr $FORMULA_DIR/vs2015/*.h include/libxml/
        cp -r $FORMULA_DIR/vs2015/* win32/VC10/
    fi
}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "vs" ] ; then
        unset TMP
        unset TEMP
        cd win32/VC10

        vs-upgrade libxml2.vcxproj

        if [ $ARCH == 32 ] ; then
            vs-build libxml2.vcxproj Build "Release|Win32"
        else
            vs-build libxml2.vcxproj Build "Release|x64"
        fi

    elif [ "$TYPE" == "android" ]; then
        cp $FORMULA_DIR/config.h .

        find . -name "test*.c" | xargs rm
        find . -name "run*.c" | xargs rm
        
        source ../../android_configure.sh $ABI cmake
        mkdir -p cmake
        cd cmake
        # ln -s .. libxml2

        cp -fr $FORMULA_DIR/CMakeLists.txt .
        #wget https://raw.githubusercontent.com/martell/libxml2.cmake/master/CmakeLists.txt
        perl -pi -e 's|^include_directories\("\$\{XML2_SOURCE_DIR\}/win32/VC10"\)|#include_directories\("\${XML2_SOURCE_DIR}/win32/VC10"\)|g' CMakeLists.txt
        cd ..

        mkdir -p build_$ABI
        cd build_$ABI
        
        export CMAKE_CFLAGS="$CFLAGS"
        export CFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
        export LDFLAGS=""
        cmake .. -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI=$ABI \
            -DANDROID_TOOLCHAIN=clang++ \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c++17 -Wno-implicit-function-declaration -frtti -msse2" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fvisibility-inlines-hidden -std=c17 -Wno-implicit-function-declaration -frtti -msse2  " \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DLIBXML2_WITH_LZMA=NO \
            -DBUILD_SHARED_LIBS=NO \
            -DLIBXML2_WITH_FTP=NO \
            -DLIBXML2_WITH_HTTP=NO \
            -DLIBXML2_WITH_HTML=NO \
            -DLIBXML2_WITH_ICONV=NO \
            -DLIBXML2_WITH_LEGACY=NO \
            -DLIBXML2_WITH_MODULES=NO \
            -DLIBXML_THREAD_ENABLED=NO \
            -DLIBXML2_WITH_OUTPUT=YES \
            -DLIBXML2_WITH_PYTHON=NO \
            -DLIBXML2_WITH_DEBUG=NO \
            -DLIBXML2_WITH_THREADS=ON \
            -DLIBXML2_WITH_TESTS=NO \
            -DCMAKE_BUILD_TYPE=Release \
            -DLIBXML2_WITH_THREAD_ALLOC=NO \
            -G 'Unix Makefiles' 

        make -j${PARALLEL_MAKE} VERBOSE=1
        cd ..

        # unlink cmake/libxml2

        #source ../../android_configure.sh $ABI
        #wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        #wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
        #if [ "$ARCH" == "armv7" ]; then
        #    HOST=armv7a-linux-android
        #elif [ "$ARCH" == "x86" ]; then
        #    HOST=x86-linux-android
        #fi
        #./configure --host=$HOST --without-lzma --without-zlib --disable-shared --enable-static --with-sysroot=$SYSROOT --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        #make clean
        #make -j${PARALLEL_MAKE}
    elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"

        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}


    elif [ "$TYPE" == "emscripten" ]; then
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
        emconfigure ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        emmake make clean
        emmake make -j${PARALLEL_MAKE}


    elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "msys2" ]; then
        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ]; then
        source ../../${TYPE}_configure.sh
        export CFLAGS="$CFLAGS -DTRIO_FPCLASSIFY=fpclassify"
        sed -i "s/#if defined.STANDALONE./#if 0/g" trionan.c
        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python --without-schematron --without-threads --host $HOST
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

        ./configure --without-lzma --without-zlib --disable-shared --enable-static --without-ftp --without-html --without-http --without-iconv --without-legacy --without-modules --without-output --without-python
        make clean
        make -j${PARALLEL_MAKE}

    elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
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

    # prepare libs directory if needed
    mkdir -p $1/lib/$TYPE
    cp -Rv include/libxml/* $1/include/libxml/

    if [ "$TYPE" == "vs" ] ; then
        if [ $ARCH == 32 ] ; then
            mkdir -p $1/lib/$TYPE/Win32
            cp -v "win32/VC10/Release/libxml2.lib" $1/lib/$TYPE/Win32/
        elif [ $ARCH == 64 ] ; then
            mkdir -p $1/lib/$TYPE/x64
            cp -v "win32/VC10/x64/Release/libxml2.lib" $1/lib/$TYPE/x64/
        fi
    elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        # copy lib
        cp -Rv .libs/libxml2.a $1/lib/$TYPE/xml2.a
    elif [ "$TYPE" == "android" ] ; then
        mkdir -p $1/lib/$TYPE/$ABI
        # copy lib
        cp -Rv build_$ABI/libxml2.a $1/lib/$TYPE/$ABI/libxml2.a
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
