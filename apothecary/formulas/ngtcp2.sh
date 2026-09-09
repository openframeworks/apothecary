#!/usr/bin/env bash
#
# ngtcp2 - QUIC transport library with the OpenSSL 3.5+ crypto helper
# https://github.com/ngtcp2/ngtcp2

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "watchos" "android" "linux")
FORMULA_DEPENDS=("openssl")

VER=1.25.0
SHA256="1c0843076528a87b65e9a9d455100941f4cb65d44f96c5da6ae56df146043955"
BUILD_ID=2
DEFINES="-DNGTCP2_STATICLIB"

GIT_URL=https://github.com/ngtcp2/ngtcp2
GIT_TAG=v$VER

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/releases/download/v$VER/ngtcp2-$VER.tar.gz"
    verify_sha256 "ngtcp2-$VER.tar.gz" "$SHA256"
    tar -xf "ngtcp2-$VER.tar.gz"
    mv "ngtcp2-$VER" ngtcp2
    rm -f "ngtcp2-$VER.tar.gz"
}

function prepare() {
    :
}

function build() {
    local LIBS_ROOT OPENSSL_ROOT BUILD_DIR
    LIBS_ROOT=$(realpath "$LIBS_DIR")
    OPENSSL_ROOT="$LIBS_ROOT/openssl"
    BUILD_DIR="build_${TYPE}_${PLATFORM}"
    local OPENSSL_ROOT_CMAKE="$OPENSSL_ROOT"
    local OPENSSL_INCLUDE_CMAKE="$OPENSSL_ROOT/include"
    local PLATFORM_ARGS=()

    if [ "$TYPE" == "vs" ]; then
        unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
        local OPENSSL_SSL_POSIX="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.lib"
        local OPENSSL_CRYPTO_POSIX="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.lib"
        if [ ! -f "$OPENSSL_SSL_POSIX" ] || [ ! -f "$OPENSSL_CRYPTO_POSIX" ]; then
            echo "Missing packaged OpenSSL libraries for $TYPE/$PLATFORM:"
            echo "  $OPENSSL_SSL_POSIX"
            echo "  $OPENSSL_CRYPTO_POSIX"
            exit 1
        fi
        local OPENSSL_ROOT_WINDOWS OPENSSL_INCLUDE_WINDOWS OPENSSL_SSL_WINDOWS OPENSSL_CRYPTO_WINDOWS
        OPENSSL_ROOT_WINDOWS=$(cygpath -m "$OPENSSL_ROOT")
        OPENSSL_INCLUDE_WINDOWS=$(cygpath -m "$OPENSSL_ROOT/include")
        OPENSSL_SSL_WINDOWS=$(cygpath -m "$OPENSSL_SSL_POSIX")
        OPENSSL_CRYPTO_WINDOWS=$(cygpath -m "$OPENSSL_CRYPTO_POSIX")
        OPENSSL_ROOT_CMAKE="$OPENSSL_ROOT_WINDOWS"
        OPENSSL_INCLUDE_CMAKE="$OPENSSL_INCLUDE_WINDOWS"
        PLATFORM_ARGS=(
            -G "Visual Studio ${VS_VER_GEN}"
            -A "$PLATFORM"
            ${CMAKE_WIN_SDK}
            -DOPENSSL_ROOT_DIR:PATH="$OPENSSL_ROOT_WINDOWS"
            -DOPENSSL_INCLUDE_DIR:PATH="$OPENSSL_INCLUDE_WINDOWS"
            -DOPENSSL_SSL_LIBRARY:FILEPATH="$OPENSSL_SSL_WINDOWS"
            -DOPENSSL_CRYPTO_LIBRARY:FILEPATH="$OPENSSL_CRYPTO_WINDOWS"
            -DSSL_EAY_RELEASE:FILEPATH="$OPENSSL_SSL_WINDOWS"
            -DSSL_EAY_DEBUG:FILEPATH="$OPENSSL_SSL_WINDOWS"
            -DLIB_EAY_RELEASE:FILEPATH="$OPENSSL_CRYPTO_WINDOWS"
            -DLIB_EAY_DEBUG:FILEPATH="$OPENSSL_CRYPTO_WINDOWS"
            -DOPENSSL_USE_STATIC_LIBS:BOOL=ON
        )
    elif [ "$TYPE" == "android" ]; then
        source "$APOTHECARY_DIR/configure/android_configure.sh" "$ABI" cmake
        PLATFORM_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/android.toolchain.cmake"
            -DANDROID_ABI="$ABI"
            -DANDROID_API="$ANDROID_API"
            -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
        )
    elif [ "$TYPE" == "linux" ]; then
        PLATFORM_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake"
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
        )
    else
        PLATFORM_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
            -DPLATFORM="$PLATFORM"
            -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
            -DENABLE_BITCODE=OFF
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
        )
    fi

    rm -rf "$BUILD_DIR"
    cmake -S . -B "$BUILD_DIR" \
        "${PLATFORM_ARGS[@]}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/Release" \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DENABLE_STATIC_LIB=ON \
        -DENABLE_SHARED_LIB=OFF \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_OPENSSL=ON \
        -DENABLE_BORINGSSL=OFF \
        -DENABLE_GNUTLS=OFF \
        -DENABLE_PICOTLS=OFF \
        -DENABLE_WOLFSSL=OFF \
        -DENABLE_WERROR=OFF \
        -DBUILD_TESTING=OFF \
        -DOPENSSL_ROOT_DIR:PATH="$OPENSSL_ROOT_CMAKE" \
        -DOPENSSL_INCLUDE_DIR:PATH="$OPENSSL_INCLUDE_CMAKE"

    grep -q '^HAVE_SSL_SET_QUIC_TLS_CBS:INTERNAL=1$' "$BUILD_DIR/CMakeCache.txt" || {
        echo "ngtcp2 could not verify the OpenSSL QUIC API"
        exit 1
    }
    cmake --build "$BUILD_DIR" --config Release -j"${PARALLEL_MAKE}" --target install
}

function copy() {
    local BUILD_DIR="build_${TYPE}_${PLATFORM}/Release"
    local EXTENSION=a
    local TRANSPORT_NAME=libngtcp2.a
    local CRYPTO_NAME=libngtcp2_crypto_ossl.a
    if [ "$TYPE" == "vs" ]; then
        EXTENSION=lib
        TRANSPORT_NAME=ngtcp2.lib
        CRYPTO_NAME=ngtcp2_crypto_ossl.lib
    fi

    mkdir -p "$1/include/ngtcp2" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -Rv "$BUILD_DIR/include/"* "$1/include/"
    # curl FindNGTCP2 reads include/ngtcp2/version.h for NGTCP2_VERSION.
    # An empty version is treated as < 1.12.0 and fails OpenSSL QUIC.
    local VERSION_H="$BUILD_DIR/include/ngtcp2/version.h"
    if [ ! -f "$VERSION_H" ]; then
        VERSION_H="build_${TYPE}_${PLATFORM}/lib/includes/ngtcp2/version.h"
    fi
    if [ -f "$VERSION_H" ]; then
        cp -v "$VERSION_H" "$1/include/ngtcp2/version.h"
    elif [ ! -f "$1/include/ngtcp2/version.h" ]; then
        printf '#define NGTCP2_VERSION "%s"\n' "$VER" >"$1/include/ngtcp2/version.h"
        echo " wrote $1/include/ngtcp2/version.h (NGTCP2_VERSION=$VER)"
    fi
    if ! grep -q 'NGTCP2_VERSION' "$1/include/ngtcp2/version.h"; then
        echo "ngtcp2 version.h is missing NGTCP2_VERSION"
        exit 1
    fi
    cp -v "$BUILD_DIR/lib/$TRANSPORT_NAME" "$1/lib/$TYPE/$PLATFORM/ngtcp2.$EXTENSION"
    cp -v "$BUILD_DIR/lib/$CRYPTO_NAME" "$1/lib/$TYPE/$PLATFORM/ngtcp2_crypto_ossl.$EXTENSION"
    cp -v COPYING "$1/license/"

    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/ngtcp2.$EXTENSION" "ngtcp2.pkl" \
        "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
}

function clean() {
    local BUILD_DIR="build_${TYPE}_${PLATFORM}"
    [ -d "$BUILD_DIR" ] && rm -r "$BUILD_DIR"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "ngtcp2" "$ARCH" "$VER" \
        "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    [ "$PREBUILT" -eq 1 ] && echo 1 || echo 0
}
