#!/usr/bin/env bash
#
# curl
# creating windows with OpenGL contexts and managing input and events
# https://github.com/curl/curl/
#
# uses a CMake build system

FORMULA_TYPES=( "vs" "osx" "ios" "xros" "tvos" "catos")
FORMULA_DEPENDS=( "openssl" "zlib" "brotli" )

# Android to implementation 'com.android.ndk.thirdparty:curl:7.79.1-beta-1'


VER=8.11.0
VER_D=8_11_0
SHA1=9648c31756362343f1a0daba881e189d6fe8b4f4
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/curl/curl
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"

    downloader $GIT_URL/releases/download/curl-$VER_D/curl-$VER.tar.gz
    tar -xf curl-$VER.tar.gz
    mv curl-$VER curl
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

    # cp -f $FORMULA_DIR/CMakeLists.txt .

    apothecaryDepend prepare brotli
    apothecaryDepend build brotli
    apothecaryDepend copy brotli
  
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib  

    apothecaryDepend prepare openssl
    apothecaryDepend build openssl
    apothecaryDepend copy openssl  

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        patch -p1 < "$FORMULA_DIR/apple-patch.diff"
        if [ $? -ne 0 ]; then
            echo "Failed to apply apple-patch.diff"
            exit 1
        else
            echo "apple-patch.diff applied successfully"
        fi
    fi 
    echo "prepared"


}

# executed inside the lib src dir
function build() {

    LIBS_ROOT=$(realpath $LIBS_DIR)
    if [[ ! "$TYPE" =~ ^(tvos|catos|watchos)$ ]]; then
        export OF_LIBS_OPENSSL_ABS_PATH=$(realpath ${LIBS_DIR}/)
        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
        local OF_LIBS_OPENSSL_ABS_PATH=`realpath $OF_LIBS_OPENSSL`
         export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
    fi
	
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
        rm -f CMakeCache.txt *.a *.o *.lib

        OPENSSL_ROOT="$LIBS_ROOT/openssl/"
        OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
        OPENSSL_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/openssl.lib"
        OPENSSL_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/libcrypto.lib"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"
        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM"
        LIBBROTLI_COMMON_LIB="$LIBBROTLI_LIBRARY/brotlicommon.lib"
        LIBBROTLI_ENC_LIB="$LIBBROTLI_LIBRARY/brotlienc.lib"
        LIBBROTLI_DEC_LIB="$LIBBROTLI_LIBRARY/brotlidec.lib"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig;${PKG_CONFIG_PATH};${OF_LIBS_OPENSSL}/lib/$TYPE/$PLATFORM;${ZLIB_ROOT}/lib/$TYPE/$PLATFORM;${LIBBROTLI_ROOT}/lib/$TYPE/$PLATFORM"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"              
        cmake .. ${DEFS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CPP_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCURL_TARGET_WINDOWS_VERSION=${CMAKE_WIN_SDK_HEX} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_STATICLIB=ON \
            -DBUILD_STATIC_LIBS=ON \
            -DBUILD_STATIC_CURL=ON \
            -DCURL_STATICLIB=ON \
            -DBUILD_STATIC_LIBS=ON \
            -DUSE_LIBIDN2=OFF \
            -DENABLE_UNICODE=ON \
            -DCURL_USE_OPENSSL=ON \
            -DUSE_SSLEAY=ON \
            -DUSE_OPENSSL=ON \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_LIBRARIES=${ZLIB_LIBRARY} \
            -DCURL_BROTLI=ON \
            -DBROTLIDEC_LIBRARY=${LIBBROTLI_DEC_LIB} \
            -DBROTLICOMMON_LIBRARY=${LIBBROTLI_COMMON_LIB} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_LIBRARIES="${LIBBROTLI_COMMON_LIB} ;${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB}" \
            -DBROTLI_INCLUDE_DIRS="${LIBBROTLI_INCLUDE_DIR}" \
            -DUSE_RESOLVE_ON_IPS=OFF \
            -DENABLE_ARES=OFF \
            -DHAVE__FSEEKI64=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
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

        export CFLAGS="-std=c${C_STANDARD}"
        export CXXFLAGS="-D__ANDROID_MIN_SDK_VERSION__=${ANDROID_API} $MAKE_INCLUDES_CFLAGS -std=c++${CPP_STANDARD}"
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

	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then


        if [[ ! "$TYPE" =~ ^(tvos|catos|watchos)$ ]]; then
            export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
            OPENSSL_ROOT="$LIBS_ROOT/openssl/"
            OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
            OPENSSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a" 
            OPENSSL_LIBRARY_CRYPT="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a" 
            USE_SECURE_TRANSPORT=OFF
            CURL_ENABLE_SSL=ON
            SSL_DEFS="-DOPENSSL_ROOT_DIR=${OF_LIBS_OPENSSL_ABS_PATH} \
                -DOPENSSL_INCLUDE_DIR=${OF_LIBS_OPENSSL_ABS_PATH}/include \
                -DOPENSSL_LIBRARIES=${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libssl.a:${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.a"
        else
            # disabled for tvOS SSL
            OPENSSL_ROOT="$LIBS_ROOT"
            OPENSSL_INCLUDE_DIR=""
            OPENSSL_LIBRARY="" 
            OPENSSL_LIBRARY_CRYPT=""
            USE_SECURE_TRANSPORT=ON
            OPENSSL_PATH=""
            OF_LIBS_OPENSSL_ABS_PATH=""
            CURL_ENABLE_SSL=OFF
            SSL_DEFS=""

        fi

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"

        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlicommon.a"
        LIBBROTLI_ENC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlienc.a"
        LIBBROTLI_DEC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlidec.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${OPENSSL_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM:${LIBBROTLI_ROOT}/lib/$TYPE/$PLATFORM"

        echo "building curl $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o *.lib
        cmake  .. \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DENABLE_STRICT_TRY_COMPILE=ON \
            -DHAVE_GETPASS_R=0 \
            -DCURL_USE_LIBSSH2=OFF \
            -DCURL_USE_LIBPSL=OFF \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_IGNORE_PATH=/opt/homebrew \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DCURL_STATICLIB=ON \
            -DBUILD_STATIC_LIBS=ON \
            -DENABLE_UNICODE=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DHAVE__FSEEKI64=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DCMAKE_USE_SYSTEM_CURL=OFF \
            -DENABLE_ARC=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DCURL_DISABLE_LDAP=ON \
            -DENABLE_VISIBILITY=OFF \
            ${SSL_DEFS} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_LIBRARIES=${ZLIB_LIBRARY} \
            -DENABLE_ARES=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DENABLE_UNIX_SOCKETS=OFF \
            -DHAVE_LIBSOCKET=OFF \
            -DCURL_ENABLE_SSL=${CURL_ENABLE_SSL} \
            -DCMAKE_MACOSX_BUNDLE=OFF \
            -DUSE_SECURE_TRANSPORT=${USE_SECURE_TRANSPORT} \
            -DCURL_USE_SECTRANSP=${USE_SECURE_TRANSPORT} \
            -DUSE_NGHTTP2=OFF \
            -DCURL_DISABLE_POP3=ON \
            -DCURL_CA_FALLBACK=ON \
            -DCURL_DISABLE_IMAP=ON \
            -DENABLE_WEBSOCKETS=ON \
            -DENABLE_UNIX_SOCKETS=ON \
            -DCURL_BROTLI=ON \
            -DBROTLI_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLIDEC_LIBRARY=${LIBBROTLI_DEC_LIB} \
            -DBROTLICOMMON_LIBRARY=${LIBBROTLI_LIBRARY} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_LIBRARIES="${LIBBROTLI_LIBRARY} ;${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB}" \
            -DUSE_LIBIDN2=OFF \
            -DENABLE_VERBOSE=ON \
            -DENABLE_THREADED_RESOLVER=ON \
            -DENABLE_IPV6=ON
        cmake --build . --config Release --target install
        cd ..

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
    mkdir -p $1/include
    . "$SECURE_SCRIPT"

	if [ "$TYPE" == "vs" ] ; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include 
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${ARCH}/Release/bin/"* $1/bin
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libcurl.lib" $1/lib/$TYPE/$PLATFORM/libcurl.lib
        secure $1/lib/$TYPE/$PLATFORM/libcurl.lib curl.pkl
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/bin/"* $1/bin
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a" $1/lib/$TYPE/$PLATFORM/curl.a
        secure $1/lib/$TYPE/$PLATFORM/curl.a curl.pkl
	elif [ "$TYPE" == "android" ] ; then
        mkdir -p $1/lib/$TYPE/$ABI
        cp -Rv build/$TYPE/$ABI/include/* $1/include/curl/
        cp -Rv build/$TYPE/$ABI/lib/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
        secure $1/lib/$TYPE/$ABI/libcurl.a curl.pkl
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
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "vs" ] ; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
	else
		make clean
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "curl" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
