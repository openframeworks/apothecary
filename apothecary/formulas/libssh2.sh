#!/usr/bin/env bash
#
# libssh2 - SSH2 client library used by curl for SCP and SFTP
# https://github.com/libssh2/libssh2

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "watchos" "android" "linux")
FORMULA_DEPENDS=("zlib" "openssl")

VER=1.11.1
SHA256="d9ec76cbe34db98eec3539fe2c899d26b0c837cb3eb466a56b0f109cabf658f7"
BUILD_ID=2
DEFINES="-DLIBSSH2_OPENSSL -DLIBSSH2_HAVE_ZLIB"

GIT_URL=https://github.com/libssh2/libssh2
GIT_TAG=libssh2-$VER

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/releases/download/libssh2-$VER/libssh2-$VER.tar.gz"
    verify_sha256 "libssh2-$VER.tar.gz" "$SHA256"
    tar -xf "libssh2-$VER.tar.gz"
    mv "libssh2-$VER" libssh2
    rm -f "libssh2-$VER.tar.gz"
}

function prepare() {
    :
}

function build() {
    local LIBS_ROOT
    LIBS_ROOT=$(realpath "$LIBS_DIR")
    local OPENSSL_ROOT="$LIBS_ROOT/openssl"
    local ZLIB_ROOT="$LIBS_ROOT/zlib"
    local BUILD_DIR="build_${TYPE}_${PLATFORM}"
    local OPENSSL_ROOT_CMAKE="$OPENSSL_ROOT"
    local OPENSSL_INCLUDE_CMAKE="$OPENSSL_ROOT/include"
    local ZLIB_ROOT_CMAKE="$ZLIB_ROOT"
    local ZLIB_INCLUDE_CMAKE="$ZLIB_ROOT/include"
    local PLATFORM_ARGS=()

    if [ "$TYPE" == "vs" ]; then
        unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
        local OPENSSL_SSL_POSIX="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.lib"
        local OPENSSL_CRYPTO_POSIX="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.lib"
        local ZLIB_POSIX="$ZLIB_ROOT/lib/$TYPE/$PLATFORM/zlib.lib"
        if [ ! -f "$OPENSSL_SSL_POSIX" ] || [ ! -f "$OPENSSL_CRYPTO_POSIX" ] || [ ! -f "$ZLIB_POSIX" ]; then
            echo "Missing packaged dependencies for libssh2 $TYPE/$PLATFORM"
            exit 1
        fi
        local OPENSSL_ROOT_WINDOWS OPENSSL_INCLUDE_WINDOWS OPENSSL_SSL_WINDOWS OPENSSL_CRYPTO_WINDOWS
        local ZLIB_ROOT_WINDOWS ZLIB_INCLUDE_WINDOWS ZLIB_WINDOWS
        OPENSSL_ROOT_WINDOWS=$(cygpath -m "$OPENSSL_ROOT")
        OPENSSL_INCLUDE_WINDOWS=$(cygpath -m "$OPENSSL_ROOT/include")
        OPENSSL_SSL_WINDOWS=$(cygpath -m "$OPENSSL_SSL_POSIX")
        OPENSSL_CRYPTO_WINDOWS=$(cygpath -m "$OPENSSL_CRYPTO_POSIX")
        ZLIB_ROOT_WINDOWS=$(cygpath -m "$ZLIB_ROOT")
        ZLIB_INCLUDE_WINDOWS=$(cygpath -m "$ZLIB_ROOT/include")
        ZLIB_WINDOWS=$(cygpath -m "$ZLIB_POSIX")
        OPENSSL_ROOT_CMAKE="$OPENSSL_ROOT_WINDOWS"
        OPENSSL_INCLUDE_CMAKE="$OPENSSL_INCLUDE_WINDOWS"
        ZLIB_ROOT_CMAKE="$ZLIB_ROOT_WINDOWS"
        ZLIB_INCLUDE_CMAKE="$ZLIB_INCLUDE_WINDOWS"
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
            -DZLIB_ROOT:PATH="$ZLIB_ROOT_WINDOWS"
            -DZLIB_INCLUDE_DIR:PATH="$ZLIB_INCLUDE_WINDOWS"
            -DZLIB_LIBRARY:FILEPATH="$ZLIB_WINDOWS"
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
            -DZLIB_LIBRARY="$ZLIB_ROOT/lib/$TYPE/$PLATFORM/zlib.a"
        )
    elif [ "$TYPE" == "linux" ]; then
        PLATFORM_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake"
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
            -DZLIB_LIBRARY="$ZLIB_ROOT/lib/$TYPE/$PLATFORM/zlib.a"
        )
    else
        PLATFORM_ARGS=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
            -DPLATFORM="$PLATFORM"
            -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
            -DENABLE_BITCODE=OFF
            -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libssl.a"
            -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/lib/$TYPE/$PLATFORM/libcrypto.a"
            -DZLIB_LIBRARY="$ZLIB_ROOT/lib/$TYPE/$PLATFORM/zlib.a"
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
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DENABLE_WERROR=OFF \
        -DCRYPTO_BACKEND=OpenSSL \
        -DOPENSSL_ROOT_DIR:PATH="$OPENSSL_ROOT_CMAKE" \
        -DOPENSSL_INCLUDE_DIR:PATH="$OPENSSL_INCLUDE_CMAKE" \
        -DZLIB_ROOT:PATH="$ZLIB_ROOT_CMAKE" \
        -DZLIB_INCLUDE_DIR:PATH="$ZLIB_INCLUDE_CMAKE"

    cmake --build "$BUILD_DIR" --config Release -j"${PARALLEL_MAKE}" --target install
    grep -q '^CRYPTO_BACKEND:STRING=OpenSSL$' "$BUILD_DIR/CMakeCache.txt" || {
        echo "libssh2 configured without OpenSSL"
        exit 1
    }
}

function copy() {
    local BUILD_DIR="build_${TYPE}_${PLATFORM}/Release"
    local EXTENSION=a
    [ "$TYPE" == "vs" ] && EXTENSION=lib

    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -Rv "$BUILD_DIR/include/"* "$1/include/"
    cp -v "$BUILD_DIR/lib/libssh2.$EXTENSION" "$1/lib/$TYPE/$PLATFORM/libssh2.$EXTENSION"
    cp -v COPYING "$1/license/"

    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/libssh2.$EXTENSION" "libssh2.pkl" \
        "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
}

function clean() {
    local BUILD_DIR="build_${TYPE}_${PLATFORM}"
    [ -d "$BUILD_DIR" ] && rm -r "$BUILD_DIR"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "libssh2" "$ARCH" "$VER" \
        "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    [ "$PREBUILT" -eq 1 ] && echo 1 || echo 0
}
