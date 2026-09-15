#!/usr/bin/env bash
#
# curl
# creating windows with OpenGL contexts and managing input and events
# https://github.com/curl/curl/
#
# uses a CMake build system

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "watchos" "android" "linux")
FORMULA_DEPENDS=("openssl" "zlib" "brotli" "nghttp2" "nghttp3" "ngtcp2" "libssh2")

# Android to implementation 'com.android.ndk.thirdparty:curl:7.79.1-beta-1'

VER=8.21.0
VER_D=8_21_0
SHA1="c4a973118684745cb03c38987d131ccbce9e7ab1"
SHA256="d9b327997999045a24cda50f3983e69e51c516bd8be6ef9842fc7f99135e33bb"
CACERT_DATE=2026-07-16
CACERT_SHA256="3ff344e30b9b1ed2971044eabb438a08f2e2245ddb5f8ab1a3ad8b63ab4eaf91"
BUILD_ID=10
DEFINES=""
USE_OPENSSL=ON

# tools for git use
GIT_URL=https://github.com/curl/curl
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"

    downloader $GIT_URL/releases/download/curl-$VER_D/curl-$VER.tar.gz
    verify_sha256 "curl-$VER.tar.gz" "$SHA256"
    tar -xf curl-$VER.tar.gz
    mv curl-$VER curl
    rm curl*.tar.gz

    curl -L "https://curl.se/ca/cacert-${CACERT_DATE}.pem" -o cacert.pem
    verify_sha256 cacert.pem "$CACERT_SHA256"
    cp cacert.pem curl/src/cacert.pem
    mv cacert.pem curl/cacert.pem

}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "prepare"

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        if grep -q 'char \*input = getpass(prompt);' src/tool_paramhlp.c; then
            echo "apple-patch.diff already applied"
        elif patch --batch --forward -p1 <"$FORMULA_DIR/apple-patch.diff"; then
            echo "apple-patch.diff applied successfully"
        else
            echo "Failed to apply apple-patch.diff"
            exit 1
        fi
    fi
    echo "prepared"




}

function verify_required_features() {
    local CONFIG_HEADER="$1"
    local FEATURE
    for FEATURE in USE_NGHTTP2 USE_NGTCP2 USE_NGHTTP3 USE_LIBSSH2; do
        if ! grep -q "^#define ${FEATURE} 1$" "$CONFIG_HEADER"; then
            echo "curl configured without required feature ${FEATURE}"
            exit 1
        fi
    done
}

function merge_unix_curl_dependencies() {
    local CURL_LIBRARY="$1"
    shift

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        local MERGED_LIBRARY="${CURL_LIBRARY}.merged"
        /usr/bin/libtool -static -o "$MERGED_LIBRARY" "$CURL_LIBRARY" "$@"
        mv "$MERGED_LIBRARY" "$CURL_LIBRARY"
    elif [ "$TYPE" == "linux" ]; then
        local MERGE_SCRIPT="${CURL_LIBRARY}.mri"
        local MERGED_LIBRARY="${CURL_LIBRARY}.merged"
        local ARCHIVER="${AR:-}"
        local RANLIB_TOOL="${RANLIB:-}"
        if [ -z "$ARCHIVER" ] && [ -n "${TOOLCHAIN_PREFIX:-}" ]; then
            ARCHIVER=$(command -v "${TOOLCHAIN_PREFIX}-ar" || true)
        fi
        if [ -z "$RANLIB_TOOL" ] && [ -n "${TOOLCHAIN_PREFIX:-}" ]; then
            RANLIB_TOOL=$(command -v "${TOOLCHAIN_PREFIX}-ranlib" || true)
        fi
        ARCHIVER=${ARCHIVER:-$(command -v ar)}
        RANLIB_TOOL=${RANLIB_TOOL:-$(command -v ranlib)}
        if [ -z "$ARCHIVER" ] || [ -z "$RANLIB_TOOL" ]; then
            echo "Unable to find the Linux archive tools"
            exit 1
        fi
        rm -f "$MERGED_LIBRARY" "$MERGE_SCRIPT"
        {
            echo "create $MERGED_LIBRARY"
            echo "addlib $CURL_LIBRARY"
            local DEPENDENCY
            for DEPENDENCY in "$@"; do
                echo "addlib $DEPENDENCY"
            done
            echo save
            echo end
        } >"$MERGE_SCRIPT"
        "$ARCHIVER" -M <"$MERGE_SCRIPT"
        "$RANLIB_TOOL" "$MERGED_LIBRARY"
        mv "$MERGED_LIBRARY" "$CURL_LIBRARY"
        rm -f "$MERGE_SCRIPT"
    else
        local MERGE_SCRIPT="${CURL_LIBRARY}.mri"
        local MERGED_LIBRARY="${CURL_LIBRARY}.merged"
        local ARCHIVER="$TOOLCHAIN_PATH/llvm-ar"
        local RANLIB="$TOOLCHAIN_PATH/llvm-ranlib"
        if [ ! -x "$ARCHIVER" ] || [ ! -x "$RANLIB" ]; then
            echo "Unable to find the Android NDK archive tools"
            exit 1
        fi
        rm -f "$MERGED_LIBRARY" "$MERGE_SCRIPT"
        {
            echo "create $MERGED_LIBRARY"
            echo "addlib $CURL_LIBRARY"
            local DEPENDENCY
            for DEPENDENCY in "$@"; do
                echo "addlib $DEPENDENCY"
            done
            echo save
            echo end
        } >"$MERGE_SCRIPT"
        "$ARCHIVER" -M <"$MERGE_SCRIPT"
        "$RANLIB" "$MERGED_LIBRARY"
        mv "$MERGED_LIBRARY" "$CURL_LIBRARY"
        rm -f "$MERGE_SCRIPT"
    fi
}

# executed inside the lib src dir
function build() {

    LIBS_ROOT=$(realpath $LIBS_DIR)
    NGHTTP2_ROOT="$LIBS_ROOT/nghttp2"
    NGHTTP3_ROOT="$LIBS_ROOT/nghttp3"
    NGTCP2_ROOT="$LIBS_ROOT/ngtcp2"
    LIBSSH2_ROOT="$LIBS_ROOT/libssh2"
    if [ ! -f "$NGTCP2_ROOT/include/ngtcp2/version.h" ]; then
        echo " ngtcp2 version.h missing at $NGTCP2_ROOT/include/ngtcp2/version.h"
        echo " curl 8.21 treats an unknown ngtcp2 version as < 1.12.0 (OpenSSL QUIC)."
        echo " Rebuild ngtcp2, then retry curl."
        exit 1
    fi
    export OF_LIBS_OPENSSL_ABS_PATH=$(realpath ${LIBS_DIR}/)
    local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
    local OF_LIBS_OPENSSL_ABS_PATH=$(realpath $OF_LIBS_OPENSSL)
    export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH

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

        NGHTTP2_LIBRARY="$NGHTTP2_ROOT/lib/$TYPE/$PLATFORM/nghttp2.lib"
        NGHTTP3_LIBRARY="$NGHTTP3_ROOT/lib/$TYPE/$PLATFORM/nghttp3.lib"
        NGTCP2_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2.lib"
        NGTCP2_CRYPTO_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2_crypto_ossl.lib"
        LIBSSH2_LIBRARY="$LIBSSH2_ROOT/lib/$TYPE/$PLATFORM/libssh2.lib"

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

        # The Visual Studio build runs from an MSYS2 shell in CI. Do not let
        # pkg-config inject MinGW's native headers (for example vadefs.h) into
        # an MSVC project, especially when cross-compiling for ARM64/ARM64EC.
        unset PKG_CONFIG_PATH
        unset PKG_CONFIG_SYSTEM_INCLUDE_PATH
        unset PKG_CONFIG_SYSTEM_LIBRARY_PATH

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
            -DNGHTTP2_USE_STATIC_LIBS=ON \
            -DNGHTTP2_INCLUDE_DIR="$NGHTTP2_ROOT/include" \
            -DNGHTTP2_LIBRARY="$NGHTTP2_LIBRARY" \
            -DUSE_NGTCP2=ON \
            -DNGTCP2_USE_STATIC_LIBS=ON \
            -DNGTCP2_INCLUDE_DIR="$NGTCP2_ROOT/include" \
            -DNGTCP2_LIBRARY="$NGTCP2_LIBRARY" \
            -DNGTCP2_CRYPTO_OSSL_LIBRARY="$NGTCP2_CRYPTO_LIBRARY" \
            -DNGHTTP3_USE_STATIC_LIBS=ON \
            -DNGHTTP3_INCLUDE_DIR="$NGHTTP3_ROOT/include" \
            -DNGHTTP3_LIBRARY="$NGHTTP3_LIBRARY" \
            -DCURL_USE_LIBSSH2=ON \
            -DLIBSSH2_INCLUDE_DIR="$LIBSSH2_ROOT/include" \
            -DLIBSSH2_LIBRARY="$LIBSSH2_LIBRARY" \
            -DUSE_OPENSSL=ON \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_LIBRARIES=${ZLIB_LIBRARY} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCURL_BROTLI=ON \
            -DCURL_ZSTD=OFF \
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
        verify_required_features lib/curl_config.h
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        librarian=$(command -v lib.exe)
        if [ -z "$librarian" ]; then
            echo "Unable to find the Visual Studio librarian"
            exit 1
        fi
        MSYS2_ARG_CONV_EXCL='*' "$librarian" /NOLOGO \
            "/OUT:$(cygpath -w "$PWD/Release/lib/libcurl-merged.lib")" \
            "$(cygpath -w "$PWD/Release/lib/libcurl.lib")" \
            "$(cygpath -w "$NGHTTP2_LIBRARY")" \
            "$(cygpath -w "$NGHTTP3_LIBRARY")" \
            "$(cygpath -w "$NGTCP2_LIBRARY")" \
            "$(cygpath -w "$NGTCP2_CRYPTO_LIBRARY")" \
            "$(cygpath -w "$LIBSSH2_LIBRARY")"
        mv Release/lib/libcurl-merged.lib Release/lib/libcurl.lib
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
        NGHTTP2_LIBRARY="$NGHTTP2_ROOT/lib/$TYPE/$PLATFORM/nghttp2.a"
        NGHTTP3_LIBRARY="$NGHTTP3_ROOT/lib/$TYPE/$PLATFORM/nghttp3.a"
        NGTCP2_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2.a"
        NGTCP2_CRYPTO_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2_crypto_ossl.a"
        LIBSSH2_LIBRARY="$LIBSSH2_ROOT/lib/$TYPE/$PLATFORM/libssh2.a"
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
            -DCURL_DISABLE_LDAPS=ON \
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
            -DNGHTTP2_USE_STATIC_LIBS=ON \
            -DNGHTTP2_INCLUDE_DIR=${NGHTTP2_ROOT}/include \
            -DNGHTTP2_LIBRARY=${NGHTTP2_LIBRARY} \
            -DUSE_NGTCP2=ON \
            -DNGTCP2_USE_STATIC_LIBS=ON \
            -DNGTCP2_INCLUDE_DIR=${NGTCP2_ROOT}/include \
            -DNGTCP2_LIBRARY=${NGTCP2_LIBRARY} \
            -DNGTCP2_CRYPTO_OSSL_LIBRARY=${NGTCP2_CRYPTO_LIBRARY} \
            -DNGHTTP3_USE_STATIC_LIBS=ON \
            -DNGHTTP3_INCLUDE_DIR=${NGHTTP3_ROOT}/include \
            -DNGHTTP3_LIBRARY=${NGHTTP3_LIBRARY} \
            -DCURL_USE_LIBSSH2=ON \
            -DLIBSSH2_INCLUDE_DIR=${LIBSSH2_ROOT}/include \
            -DLIBSSH2_LIBRARY=${LIBSSH2_LIBRARY} \
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

        verify_required_features lib/curl_config.h

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
            cd ..
            rm -rf curl
            cd ../..
        merge_unix_curl_dependencies Release/lib/libcurl.a \
            "$NGHTTP2_LIBRARY" "$NGHTTP3_LIBRARY" "$NGTCP2_LIBRARY" \
            "$NGTCP2_CRYPTO_LIBRARY" "$LIBSSH2_LIBRARY"
        cd ..

    elif [ "$TYPE" == "linux" ]; then
        CACERT_PATH=$(realpath "$CACERT_PATH")
        OPENSSL_ROOT="$LIBS_ROOT/openssl"
        OPENSSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
        OPENSSL_LIBRARY_CRYPT="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
        ZLIB_ROOT="$LIBS_ROOT/zlib"
        ZLIB_LIBRARY="$ZLIB_ROOT/lib/$TYPE/$PLATFORM/zlib.a"
        LIBBROTLI_ROOT="$LIBS_ROOT/brotli"
        LIBBROTLI_LIBRARY="$LIBBROTLI_ROOT/lib/$TYPE/$PLATFORM/libbrotlicommon.a"
        LIBBROTLI_DEC_LIB="$LIBBROTLI_ROOT/lib/$TYPE/$PLATFORM/libbrotlidec.a"
        NGHTTP2_LIBRARY="$NGHTTP2_ROOT/lib/$TYPE/$PLATFORM/nghttp2.a"
        NGHTTP3_LIBRARY="$NGHTTP3_ROOT/lib/$TYPE/$PLATFORM/nghttp3.a"
        NGTCP2_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2.a"
        NGTCP2_CRYPTO_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2_crypto_ossl.a"
        LIBSSH2_LIBRARY="$LIBSSH2_ROOT/lib/$TYPE/$PLATFORM/libssh2.a"
        local BUILD_DIR="build_${TYPE}_${PLATFORM}"

        rm -rf "$BUILD_DIR"
        cmake -S . -B "$BUILD_DIR" \
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake" \
            -DCMAKE_C_STANDARD="${C_STANDARD}" \
            -DCMAKE_CXX_STANDARD="${CPP_STANDARD}" \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/Release" \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DBUILD_STATIC_CURL=ON \
            -DBUILD_CURL_EXE=OFF \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_TESTING=OFF \
            -DCURL_STATICLIB=ON \
            -DCURL_USE_OPENSSL=ON \
            -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
            -DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT/include" \
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_LIBRARY" \
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_LIBRARY_CRYPT" \
            -DOPENSSL_USE_STATIC_LIBS=ON \
            -DCURL_CA_FALLBACK=ON \
            -DCURL_CA_BUNDLE="$CACERT_PATH" \
            -DCURL_CA_EMBED="$CACERT_PATH" \
            -DZLIB_ROOT="$ZLIB_ROOT" \
            -DZLIB_INCLUDE_DIR="$ZLIB_ROOT/include" \
            -DZLIB_LIBRARY="$ZLIB_LIBRARY" \
            -DCURL_BROTLI=ON \
            -DBROTLI_INCLUDE_DIR="$LIBBROTLI_ROOT/include" \
            -DBROTLIDEC_LIBRARY="$LIBBROTLI_DEC_LIB" \
            -DBROTLICOMMON_LIBRARY="$LIBBROTLI_LIBRARY" \
            -DUSE_NGHTTP2=ON \
            -DNGHTTP2_USE_STATIC_LIBS=ON \
            -DNGHTTP2_INCLUDE_DIR="$NGHTTP2_ROOT/include" \
            -DNGHTTP2_LIBRARY="$NGHTTP2_LIBRARY" \
            -DUSE_NGTCP2=ON \
            -DNGTCP2_USE_STATIC_LIBS=ON \
            -DNGTCP2_INCLUDE_DIR="$NGTCP2_ROOT/include" \
            -DNGTCP2_LIBRARY="$NGTCP2_LIBRARY" \
            -DNGTCP2_CRYPTO_OSSL_LIBRARY="$NGTCP2_CRYPTO_LIBRARY" \
            -DNGHTTP3_USE_STATIC_LIBS=ON \
            -DNGHTTP3_INCLUDE_DIR="$NGHTTP3_ROOT/include" \
            -DNGHTTP3_LIBRARY="$NGHTTP3_LIBRARY" \
            -DCURL_USE_LIBSSH2=ON \
            -DLIBSSH2_INCLUDE_DIR="$LIBSSH2_ROOT/include" \
            -DLIBSSH2_LIBRARY="$LIBSSH2_LIBRARY" \
            -DCURL_USE_LIBPSL=OFF \
            -DUSE_LIBIDN2=OFF \
            -DCURL_DISABLE_LDAP=ON \
            -DCURL_DISABLE_LDAPS=ON \
            -DCURL_ZSTD=OFF \
            -DENABLE_ARES=OFF \
            -DENABLE_THREADED_RESOLVER=ON \
            -DENABLE_IPV6=ON \
            -DENABLE_WEBSOCKETS=ON

        verify_required_features "$BUILD_DIR/lib/curl_config.h"
        cmake --build "$BUILD_DIR" --config Release -j"${PARALLEL_MAKE}" --target install
        merge_unix_curl_dependencies "$BUILD_DIR/Release/lib/libcurl.a" \
            "$NGHTTP2_LIBRARY" "$NGHTTP3_LIBRARY" "$NGTCP2_LIBRARY" \
            "$NGTCP2_CRYPTO_LIBRARY" "$LIBSSH2_LIBRARY"

    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        export OPENSSL_LIBRARIES="$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM"
        OPENSSL_ROOT="$LIBS_ROOT/openssl"
        OPENSSL_INCLUDE_DIR="$OPENSSL_ROOT/include"
        OPENSSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
        OPENSSL_LIBRARY_CRYPT="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
        CURL_ENABLE_SSL="ON"
        SSL_DEFS="-DCURL_USE_OPENSSL=ON \
            -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT} \
            -DOPENSSL_INCLUDE_DIR=${OPENSSL_INCLUDE_DIR} \
            -DOPENSSL_SSL_LIBRARY=${OPENSSL_LIBRARY} \
            -DOPENSSL_CRYPTO_LIBRARY=${OPENSSL_LIBRARY_CRYPT} \
            -DOPENSSL_USE_STATIC_LIBS=ON \
            -DUSE_APPLE_SECTRUST=ON"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"

        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlicommon.a"
        LIBBROTLI_ENC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlienc.a"
        LIBBROTLI_DEC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlidec.a"
        NGHTTP2_LIBRARY="$NGHTTP2_ROOT/lib/$TYPE/$PLATFORM/nghttp2.a"
        NGHTTP3_LIBRARY="$NGHTTP3_ROOT/lib/$TYPE/$PLATFORM/nghttp3.a"
        NGTCP2_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2.a"
        NGTCP2_CRYPTO_LIBRARY="$NGTCP2_ROOT/lib/$TYPE/$PLATFORM/ngtcp2_crypto_ossl.a"
        LIBSSH2_LIBRARY="$LIBSSH2_ROOT/lib/$TYPE/$PLATFORM/libssh2.a"

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
            -DCURL_CA_BUNDLE=none \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -Wno-error=implicit-function-declaration" \
            -DENABLE_STRICT_TRY_COMPILE=ON \
            -DHAVE_GETPASS_R=0 \
            -DCURL_USE_LIBPSL=OFF \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_IGNORE_PATH=/opt/homebrew \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=BOTH \
            -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=BOTH \
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
            -DCURL_DISABLE_LDAPS=ON \
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
            -DUSE_NGHTTP2=ON \
            -DNGHTTP2_USE_STATIC_LIBS=ON \
            -DNGHTTP2_INCLUDE_DIR=${NGHTTP2_ROOT}/include \
            -DNGHTTP2_LIBRARY=${NGHTTP2_LIBRARY} \
            -DUSE_NGTCP2=ON \
            -DNGTCP2_USE_STATIC_LIBS=ON \
            -DNGTCP2_INCLUDE_DIR=${NGTCP2_ROOT}/include \
            -DNGTCP2_LIBRARY=${NGTCP2_LIBRARY} \
            -DNGTCP2_CRYPTO_OSSL_LIBRARY=${NGTCP2_CRYPTO_LIBRARY} \
            -DNGHTTP3_USE_STATIC_LIBS=ON \
            -DNGHTTP3_INCLUDE_DIR=${NGHTTP3_ROOT}/include \
            -DNGHTTP3_LIBRARY=${NGHTTP3_LIBRARY} \
            -DCURL_USE_LIBSSH2=ON \
            -DLIBSSH2_INCLUDE_DIR=${LIBSSH2_ROOT}/include \
            -DLIBSSH2_LIBRARY=${LIBSSH2_LIBRARY} \
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

        if ! grep -q '^CURL_USE_OPENSSL:BOOL=ON$' CMakeCache.txt || \
           ! grep -q '^USE_APPLE_SECTRUST:BOOL=ON$' CMakeCache.txt; then
            echo "curl configured without the required OpenSSL and Apple SecTrust backends"
            exit 1
        fi
        verify_required_features lib/curl_config.h
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "Release/lib/"
            # Rename with prefixes (including library origin to avoid duplicates)
            rm -rf curl
            mkdir curl
            mv libcurl.a curl/libcurl-original.a
            CURL_ARCHS=$(lipo -archs curl/libcurl-original.a)
            for CURL_ARCH in $CURL_ARCHS; do
                mkdir "curl/$CURL_ARCH"
                if [ "$(echo "$CURL_ARCHS" | wc -w | tr -d ' ')" -gt 1 ]; then
                    lipo curl/libcurl-original.a -thin "$CURL_ARCH" -output "curl/$CURL_ARCH/libcurl.a"
                else
                    cp curl/libcurl-original.a "curl/$CURL_ARCH/libcurl.a"
                fi
                cd "curl/$CURL_ARCH"
                ar -x libcurl.a
                rm libcurl.a
                for f in *.o; do mv "$f" "curl_${ARCH}_${CURL_ARCH}_$f"; done
                for obj in *.o; do
                    if [ -z "$(nm "$obj")" ]; then
                        echo "Removing empty object file: $obj"
                        rm -f "$obj"
                    fi
                done
                ar rcs "../../libcurl_${CURL_ARCH}.a" curl_${ARCH}_${CURL_ARCH}_*.o
                cd ../..
            done
            lipo -create libcurl_*.a -output libcurl.a
            rm -f libcurl_*.a
            echo "Verifying libcurl.a.:"
            lipo -info libcurl.a
            rm -rf curl
            cd ../..
        merge_unix_curl_dependencies Release/lib/libcurl.a \
            "$NGHTTP2_LIBRARY" "$NGHTTP3_LIBRARY" "$NGTCP2_LIBRARY" \
            "$NGTCP2_CRYPTO_LIBRARY" "$LIBSSH2_LIBRARY"
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
        secure "$1/lib/$TYPE/$PLATFORM/libcurl.lib" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        CURL_APPLE_LIBRARY="build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a"
        if ! nm -g "$CURL_APPLE_LIBRARY" | grep '_Curl_ssl_openssl' >/dev/null; then
            echo "curl built without the required OpenSSL TLS backend"
            exit 1
        fi
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/bin/"* $1/bin
        cp -v "$CURL_APPLE_LIBRARY" $1/lib/$TYPE/$PLATFORM/curl.a
        secure "$1/lib/$TYPE/$PLATFORM/curl.a" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
    elif [ "$TYPE" == "android" ] || [ "$TYPE" == "linux" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include
        mkdir -p $1/bin
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib/libcurl.a" $1/lib/$TYPE/$PLATFORM/libcurl.a
        secure "$1/lib/$TYPE/$PLATFORM/libcurl.a" "curl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
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
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten|android|linux)$ ]]; then
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
