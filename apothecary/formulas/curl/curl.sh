#!/usr/bin/env bash
#
# curl
# creating windows with OpenGL contexts and managing input and events
# https://github.com/curl/curl/
#
# uses a CMake build system

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "android")
FORMULA_DEPENDS=("openssl" "zlib" "brotli")

# Android to implementation 'com.android.ndk.thirdparty:curl:7.79.1-beta-1'

VER=8.15.0
VER_D=8_15_0
SHA1="5b4e79489e2d24da13d2fa75897f69ca5fff741e"
BUILD_ID=2
DEFINES=""
USE_OPENSSL=ON

# tools for git use
GIT_URL=https://github.com/curl/curl
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"

    downloader $GIT_URL/releases/download/curl-$VER_D/curl-$VER.tar.gz
    tar -xf curl-$VER.tar.gz
    mv curl-$VER curl
    CHECKSHA=$(shasum -a 1 curl-$VER.tar.gz | cut -d ' ' -f1)
    if [ "$CHECKSHA" != "$SHA1" ]; then
        echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
        exit 1
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi
    rm curl*.tar.gz

    curl -LO https://curl.se/ca/cacert.pem
    cp cacert.pem curl/src/cacert.pem
    mv cacert.pem curl/cacert.pem

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
        patch -p1 <"$FORMULA_DIR/apple-patch.diff"
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
        local OF_LIBS_OPENSSL_ABS_PATH=$(realpath $OF_LIBS_OPENSSL)
        export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
    fi

    local CACERT_PATH="./cacert.pem"

    if [ "$TYPE" == "vs" ]; then
         local CACERT_PATH=$(realpath "./cacert.pem")
        export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
        export OPENSSL_WINDOWS_PATH=$(cygpath -w ${OF_LIBS_OPENSSL_ABS_PATH} | sed "s/\\\/\\\\\\\\/g")

        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libssl.lib ${OPENSSL_PATH}/lib/libssl.lib # this works!
        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.lib ${OPENSSL_PATH}/lib/libcrypto.lib

        echo "building curl $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        cp ../cacert.pem ./cacert.pem
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

        if [ "$USE_OPENSSL" == "ON" ]; then
            OPENSSL_DEFS="-DCURL_USE_OPENSSL=ON \
                -DUSE_OPENSSL=ON \
                -DCURL_CA_FALLBACK=ON \
                -DCURL_CA_BUNDLE=${CACERT_PATH} \
                -DCURL_CA_EMBED=${CACERT_PATH}"
            CACERT_PATH="${CACERT_PATH}"
            OPENSSL_DEFS="${OPENSSL_DEFS} -DCURL_CA_BUNDLE=${CACERT_PATH} -DCURL_CA_EMBED=${CACERT_PATH}"
        else
            OPENSSL_DEFS="-DCURL_USE_OPENSSL=OFF -DUSE_OPENSSL=OFF -DCURL_USE_SCHANNEL=ON"
        fi

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig;${PKG_CONFIG_PATH};${OF_LIBS_OPENSSL}/lib/$TYPE/$PLATFORM;${ZLIB_ROOT}/lib/$TYPE/$PLATFORM;${LIBBROTLI_ROOT}/lib/$TYPE/$PLATFORM"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
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
            -DCURL_USE_LIBPSL=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DUSE_LIBIDN2=OFF \
            -DENABLE_UNICODE=ON \
            ${OPENSSL_DEFS} \
            -DUSE_SSLEAY=ON \
            -DUSE_NGHTTP2=ON \
            -DUSE_OPENSSL=ON \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_LIBRARIES=${ZLIB_LIBRARY} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
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
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

        rm ${OPENSSL_PATH}/lib/libssl.lib
        rm ${OPENSSL_PATH}/lib/libcrypto.lib

    elif [ "$TYPE" == "android" ]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
        OPENSSL_ROOT="$LIBS_ROOT/openssl/"
        OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
        OPENSSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a"
        OPENSSL_LIBRARY_CRYPT="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a"
        USE_SECURE_TRANSPORT=OFF
        CURL_ENABLE_SSL=ON
        SSL_DEFS="-DOPENSSL_ROOT_DIR=${OF_LIBS_OPENSSL_ABS_PATH} \
            -DOPENSSL_INCLUDE_DIR=${OF_LIBS_OPENSSL_ABS_PATH}/include \
            -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_LIBRARY_CRYPT} \
            -DOPENSSL_SSL_LIBRARY=${OPENSSL_LIBRARY} \
            -DCURL_CA_BUNDLE=$CACERT_PATH \
            -DOPENSSL_LIBRARIES=${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libssl.a;${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.a"

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
        DEFINES="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"
        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DENABLE_STRICT_TRY_COMPILE=ON \
            -DHAVE_GETPASS_R=0 \
            -DCURL_USE_LIBSSH2=OFF \
            -DCURL_USE_LIBPSL=OFF \
            -DCMAKE_IGNORE_PATH=/opt/homebrew \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DCURL_STATICLIB=ON \
            -DBUILD_STATIC_LIBS=ON \
            -DCURL_CA_FALLBACK=ON \
            -DENABLE_UNICODE=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DHAVE__FSEEKI64=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_USE_SYSTEM_CURL=OFF \
            -DENABLE_ARC=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
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
            -DUSE_SECURE_TRANSPORT=${USE_SECURE_TRANSPORT} \
            -DCURL_USE_SECTRANSP=${USE_SECURE_TRANSPORT} \
            -DUSE_NGHTTP2=ON \
            -DCURL_DISABLE_POP3=ON \
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

        echo "--------- CMakeCache.txt Content ---------"
        cat CMakeCache.txt
        echo "------------------------------------------"


        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        cd "Release/lib/"
            # Rename with prefixes (including library origin to avoid duplicates)
            mkdir -p curl
            mv libcurl.a curl/libcurl.a
            cd curl
            ar -x libcurl.a
            for f in *.o; do mv "$f" "curl_${ARCH}_$f"; done
            for obj in *.o; do
                if [ -z "$(nm "$obj")" ]; then
                    echo "Removing empty object file: $obj"
                    rm -f "$obj"
                fi
            done
            ar rcs "../libcurl.a" curl_${ARCH}_*.o
            rm -rf curl
            cd ../..
        cd ..

    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        if [[ "$TYPE" =~ ^(osx|ios|xros|catos|watchos)$ ]]; then
            export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
            OPENSSL_ROOT="$LIBS_ROOT/openssl/"
            OPENSSL_INCLUDE_DIR="$LIBS_ROOT/openssl/include"
            OPENSSL_LIBRARY="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libssl.a"
            OPENSSL_LIBRARY_CRYPT="$LIBS_ROOT/openssl/lib/$TYPE/$PLATFORM/libcrypto.a"
            export USE_SECURE_TRANSPORT="OFF"
            CURL_ENABLE_SSL="ON"
            SSL_DEFS="-DOPENSSL_ROOT_DIR=${OF_LIBS_OPENSSL_ABS_PATH} \
                -DOPENSSL_INCLUDE_DIR=${OF_LIBS_OPENSSL_ABS_PATH}/include \
                -DOPENSSL_LIBRARIES=${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libssl.a:${OF_LIBS_OPENSSL_ABS_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.a"
        else
            # Use SecureTransport on platforms that don't support OpenSSL
            OPENSSL_ROOT="$LIBS_ROOT"
            OPENSSL_INCLUDE_DIR=""
            OPENSSL_LIBRARY=""
            OPENSSL_LIBRARY_CRYPT=""
            export USE_SECURE_TRANSPORT="ON"
            OPENSSL_PATH=""
            OF_LIBS_OPENSSL_ABS_PATH=""
            CURL_ENABLE_SSL="OFF"
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
    
        cmake .. \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCURL_CA_BUNDLE="${CACERT_PATH}" \
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
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCURL_DISABLE_LDAP=ON \
            -DENABLE_VISIBILITY=OFF \
            -DCURL_DISABLE_ZSTD=ON \
            -DCURL_ZSTD=OFF \
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
            -DUSE_NGTCP2=OFF \
            -DCURL_CA_FALLBACK=ON \
            -DCURL_DISABLE_POP3=ON \
            -DCURL_CA_FALLBACK=ON \
            -DCURL_DISABLE_IMAP=ON \
            -DENABLE_WEBSOCKETS=ON \
            -DENABLE_UNIX_SOCKETS=ON \
            -DCURL_BROTLI=ON \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_FIND_ROOT_PATH="${LIBS_ROOT}" \
            -DBROTLI_INCLUDE_DIRS=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLIDEC_LIBRARY=${LIBBROTLI_DEC_LIB} \
            -DBROTLICOMMON_LIBRARY=${LIBBROTLI_LIBRARY} \
            -DBROTLI_INCLUDE_DIR=${LIBBROTLI_INCLUDE_DIR} \
            -DBROTLI_LIBRARIES="${LIBBROTLI_LIBRARY} ;${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB}" \
            -DUSE_LIBIDN2=OFF \
            -DENABLE_VERBOSE=ON \
            -DENABLE_THREADED_RESOLVER=ON \
            -DENABLE_IPV6=ON
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "Release/lib/"
            # Rename with prefixes (including library origin to avoid duplicates)
            mkdir -p curl
            mv libcurl.a curl/libcurl.a
            cd curl
            ar -x libcurl.a
            for f in *.o; do mv "$f" "curl_${ARCH}_$f"; done
            for obj in *.o; do
                if [ -z "$(nm "$obj")" ]; then
                    echo "Removing empty object file: $obj"
                    rm -f "$obj"
                fi
            done
            ar rcs "../libcurl.a" curl_${ARCH}_*.o
            echo "Verifying libcurl.a.:"
            lipo -info "libcurl.a"
            rm -rf curl
            cd ../..
        cd ..
    else
        echo "building other for $TYPE"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git
        a=blob_plain
        f=config.guess
        hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git
        a=blob_plain
        f=config.sub
        hb=HEAD
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

    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${ARCH}/Release/bin/"* $1/bin
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libcurl.lib" $1/lib/$TYPE/$PLATFORM/libcurl.lib
        secure "$1/lib/$TYPE/$PLATFORM/libcurl.lib" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/bin/"* $1/bin
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a" $1/lib/$TYPE/$PLATFORM/curl.a
        secure "$1/lib/$TYPE/$PLATFORM/curl.a" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a" $1/lib/$TYPE/$PLATFORM/libcurl.a
        secure "$1/lib/$TYPE/$PLATFORM/libcurl.a" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
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
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten|android)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    else
        make clean
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "curl" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
