#!/usr/bin/env bash
#
# curl
# creating windows with OpenGL contexts and managing input and events
# https://github.com/curl/curl/
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" )

# Android to implementation 'com.android.ndk.thirdparty:curl:7.79.1-beta-1'

#dependencies
FORMULA_DEPENDS=( "openssl" "zlib" )

# define the version by sha
VER=8_4_0
VER_D=8.4.0
SHA1=1a2af84acf92902939cac5e0f903e13a3eb82094

# tools for git use
GIT_URL=https://github.com/curl/curl.git
GIT_TAG=$VER


# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"

    curl -Lk https://github.com/curl/curl/releases/download/curl-$VER/curl-$VER_D.tar.gz -o curl-$VER.tar.gz   
    tar -xf curl-$VER.tar.gz
    mv curl-$VER_D curl 
    local CHECKSHA=$(shasum curl-$VER.tar.gz | awk '{print $1}')
    if [ "$CHECKSHA" != "$SHA1" ] ; then
        echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi
    rm curl*.tar.gz
    
    
	
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "prepare"

    apothecaryDependencies download

    cp -f $FORMULA_DIR/CMakeLists.txt .

    if [ "$TYPE" == "vs" ] || [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then

        apothecaryDepend prepare zlib
        apothecaryDepend build zlib
        apothecaryDepend copy zlib  

        apothecaryDepend prepare openssl
        apothecaryDepend build openssl
        apothecaryDepend copy openssl  
        

        echo "prepared"
    fi

}

# executed inside the lib src dir
function build() {

    LIBS_ROOT=$(realpath $LIBS_DIR)
    export OF_LIBS_OPENSSL_ABS_PATH=$(realpath ${LIBS_DIR}/)
    local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
    local OF_LIBS_OPENSSL_ABS_PATH=`realpath $OF_LIBS_OPENSSL`

    export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
	
	if [ "$TYPE" == "vs" ] ; then
		export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
		export OPENSSL_WINDOWS_PATH=$(cygpath -w ${OF_LIBS_OPENSSL_ABS_PATH} | sed "s/\\\/\\\\\\\\/g")

        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libssl.lib ${OPENSSL_PATH}/lib/libssl.lib # this works! 
        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.lib ${OPENSSL_PATH}/lib/libcrypto.lib
	        
        echo "building curl $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"

        LIBS_ROOT=$(realpath $LIBS_DIR)

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"              
        cmake .. ${DEFS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_STATICLIB=OFF \
            -DCURL_USE_OPENSSL=ON \
            -DUSE_SSLEAY=ON \
            -DUSE_OPENSSL=ON \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DUSE_RESOLVE_ON_IPS=OFF \
            -DENABLE_ARES=OFF \
            ${CMAKE_WIN_SDK} \
            -DOPENSSL_ROOT_DIR="$OF_LIBS_OPENSSL_ABS_PATH" \
            -DOPENSSL_INCLUDE_DIR="$OF_LIBS_OPENSSL_ABS_PATH/include" \
            -DOPENSSL_LIBRARIES="$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM/libcrypto.lib;$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM/libssl.lib;" \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release --target install
        cd ..

        rm ${OPENSSL_PATH}/lib/libssl.lib
        rm ${OPENSSL_PATH}/lib/libcrypto.lib

	elif [ "$TYPE" == "android" ]; then

        source ../../android_configure.sh $ABI make

        export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH/openssl
        local BUILD_TO_DIR=$BUILD_DIR/curl/build/$TYPE/$ABI
        export OPENSSL_LIBRARIES=$OPENSSL_PATH/lib/$TYPE/$ABI

        if [ "$ARCH" == "armv7" ]; then
            export HOST=armv7a-linux-android
        elif [ "$ARCH" == "arm64" ]; then
            export HOST=aarch64-linux-android
        elif [ "$ARCH" == "x86" ]; then
            export HOST=x86-linux-android
        elif [ "$ARCH" == "x86_64" ]; then
            export HOST=x86_64-linux-android
        fi

        export NDK=$ANDROID_PLATFORM 
        export HOST_TAG=$HOST_PLATFORM
        export MIN_SDK_VERSION=21 
        export SSL_DIR=$OPENSSL_LIBRARIES

        export OUTPUT_DIR=$OPENSSL_LIBRARIES
        mkdir -p build
        mkdir -p build/$TYPE
        mkdir -p build/$TYPE/$ABI
        # export DESTDIR="$BUILD_TO_DIR"

        export CFLAGS="-std=c17"
        export CXXFLAGS="-D__ANDROID_MIN_SDK_VERSION__=${ANDROID_API} $MAKE_INCLUDES_CFLAGS -std=c++17"
        # export LIBS="-L${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libssl.a -L${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libcrypto.a " # this dont work annoying
        export LDFLAGS=" ${LIBS} -shared -stdlib=libc++ -L$DEEP_TOOLCHAIN_PATH -L$TOOLCHAIN/lib/gcc/$ANDROID_POSTFIX/4.9.x/ "

        cp $DEEP_TOOLCHAIN_PATH/crtbegin_dynamic.o $SYSROOT/usr/lib/crtbegin_dynamic.o
        cp $DEEP_TOOLCHAIN_PATH/crtbegin_so.o $SYSROOT/usr/lib/crtbegin_so.o
        cp $DEEP_TOOLCHAIN_PATH/crtend_android.o $SYSROOT/usr/lib/crtend_android.o
        cp $DEEP_TOOLCHAIN_PATH/crtend_so.o $SYSROOT/usr/lib/crtend_so.o

        cp ${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libssl.a ${OPENSSL_PATH}/lib/libssl.a # this works! 
        cp ${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libcrypto.a ${OPENSSL_PATH}/lib/libcrypto.a

        echo "OPENSSL_PATH: $OPENSSL_PATH"
       

        PATH="${PATH};${OPENSSL_PATH}/lib/${TYPE}"

         ./configure \
            --host=$HOST \
            --with-openssl=$OPENSSL_PATH \
            --with-pic \
            --enable-static \
            --disable-shared \
            --disable-verbose \
            --disable-threaded-resolver \
            --enable-ipv6 \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-ldap \
            --disable-ldaps \
            --prefix=$BUILD_DIR/curl/build/$TYPE/$ABI \

        # sed -i "s/#define HAVE_GETPWUID_R 1/\/\* #undef HAVE_GETPWUID_R \*\//g" lib/curl_config.h
        make -j${PARALLEL_MAKE}
        make install

        rm $SYSROOT/usr/lib/crtbegin_dynamic.o
        rm $SYSROOT/usr/lib/crtbegin_so.o
        rm $SYSROOT/usr/lib/crtend_android.o
        rm $SYSROOT/usr/lib/crtend_so.o

        rm ${OPENSSL_PATH}/lib/libssl.a
        rm ${OPENSSL_PATH}/lib/libcrypto.a

	elif [ "$TYPE" == "osx" ]; then

        OPENSSL_ROOT="$LIBS_ROOT/openssl/"
        OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
        OPENSSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a" 
        OPENSSL_LIBRARY_CRYPT="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a" 

        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libssl.a ${OPENSSL_PATH}/lib/libssl.a # this works! 
        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.a ${OPENSSL_PATH}/lib/libcrypto.a

        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        cmake  .. \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF \
            -DOPENSSL_ROOT_DIR="$LIBS_ROOT/openssl/" \
            -DOPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include" \
            -DOPENSSL_SSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a" \
            -DOPENSSL_CRYPTO_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a" \
            -DENABLE_UNIX_SOCKETS=ON \
            -DUSE_RESOLVE_ON_IPS=OFF \
            -DCURL_ENABLE_SSL=ON \
            -DHTTP_ONLY=ON \
            -DCMAKE_MACOSX_BUNDLE=OFF \
            -DUSE_SECURE_TRANSPORT=ON -DUSE_NGHTTP2=OFF -DUSE_LIBIDN2=OFF -DENABLE_LDAP=OFF -DENABLE_LDAPS=OFF -DENABLE_VERBOSE=ON -DENABLE_THREADED_RESOLVER=OFF -DENABLE_IPV6=OFF 
        cmake --build . --config Release --target install
        cd ..

        rm ${OPENSSL_PATH}/lib/libssl.a
        rm ${OPENSSL_PATH}/lib/libcrypto.a

	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        OPENSSL_ROOT="$LIBS_ROOT/openssl/"
        OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
        OPENSSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a" 
        OPENSSL_LIBRARY_CRYPT="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a" 

        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libssl.a ${OPENSSL_PATH}/lib/libssl.a # this works! 
        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.a ${OPENSSL_PATH}/lib/libcrypto.a

        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        cmake  .. \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF \
            -DOPENSSL_ROOT_DIR="$LIBS_ROOT/openssl/" \
            -DOPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include" \
            -DOPENSSL_SSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a" \
            -DOPENSSL_CRYPTO_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a" \
            -DENABLE_UNIX_SOCKETS=ON \
            -DUSE_RESOLVE_ON_IPS=OFF \
            -DCURL_ENABLE_SSL=ON \
            -DHTTP_ONLY=ON \
            -DCMAKE_MACOSX_BUNDLE=OFF \
            -DUSE_SECURE_TRANSPORT=ON -DUSE_NGHTTP2=OFF -DUSE_LIBIDN2=OFF -DENABLE_LDAP=OFF -DENABLE_LDAPS=OFF -DENABLE_VERBOSE=ON -DENABLE_THREADED_RESOLVER=OFF -DENABLE_IPV6=OFF 
        cmake --build . --config Release --target install
        cd ..

        rm ${OPENSSL_PATH}/lib/libssl.a
        rm ${OPENSSL_PATH}/lib/libcrypto.a
    else
        echo "building other for $TYPE"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
		./configure --with-openssl=$OPENSSL_DIR --enable-static --disable-shared
        make clean
	    make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/curl

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	# Standard *nix style copy.
	# copy headers

    mkdir -p $1/include    
    mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libcurl.lib" $1/lib/$TYPE/$PLATFORM/libcurl.lib          
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a" $1/lib/$TYPE/$PLATFORM/curl.a
	elif [ "$TYPE" == "android" ] ; then
        #mkdir -p $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
        cp -Rv build/$TYPE/$ABI/include/curl/* $1/include/curl/
		# copy lib
        cp -Rv build/$TYPE/$ABI/lib/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
	fi

	# copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            # Delete the folder and its contents
            rm -r build_${TYPE}_${ARCH}     
        else
            echo "Folder does not exist."
        fi
	else
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "curl" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "curl" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
