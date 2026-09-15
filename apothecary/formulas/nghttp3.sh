#!/usr/bin/env bash
#
# nghttp3 - HTTP/3 and QPACK library
# https://github.com/ngtcp2/nghttp3

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "watchos" "android" "linux")
FORMULA_DEPENDS=()

VER=1.18.0
SHA256="2812e9c06583fa24c8dc46bdb5291310a69196352ceaca8fbe98106ff36ae7d8"
BUILD_ID=1
DEFINES="-DNGHTTP3_STATICLIB"

GIT_URL=https://github.com/ngtcp2/nghttp3
GIT_TAG=v$VER

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/releases/download/v$VER/nghttp3-$VER.tar.gz"
    verify_sha256 "nghttp3-$VER.tar.gz" "$SHA256"
    tar -xf "nghttp3-$VER.tar.gz"
    mv "nghttp3-$VER" nghttp3
    rm -f "nghttp3-$VER.tar.gz"
}

function prepare() {
    :
}

function build() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    local platform_args=()

    if [ "$TYPE" == "vs" ]; then
        unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
        platform_args=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK})
    elif [ "$TYPE" == "android" ]; then
        source "$APOTHECARY_DIR/configure/android_configure.sh" "$ABI" cmake
        platform_args=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/android.toolchain.cmake"
            -DANDROID_ABI="$ABI"
            -DANDROID_API="$ANDROID_API"
            -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
        )
    elif [ "$TYPE" == "linux" ]; then
        platform_args=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake"
        )
    else
        platform_args=(
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
            -DPLATFORM="$PLATFORM"
            -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
            -DENABLE_BITCODE=OFF
        )
    fi

    rm -rf "$build_dir"
    cmake -S . -B "$build_dir" \
        "${platform_args[@]}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$build_dir/Release" \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=ON \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DENABLE_STATIC_LIB=ON \
        -DENABLE_SHARED_LIB=OFF \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_WERROR=OFF \
        -DBUILD_TESTING=OFF

    cmake --build "$build_dir" --config Release -j"${PARALLEL_MAKE}" --target install
}

function copy() {
    local build_dir="build_${TYPE}_${PLATFORM}/Release"
    local extension=a
    local source_name=libnghttp3.a
    [ "$TYPE" == "vs" ] && extension=lib && source_name=nghttp3.lib

    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -Rv "$build_dir/include/"* "$1/include/"
    cp -v "$build_dir/lib/$source_name" "$1/lib/$TYPE/$PLATFORM/nghttp3.$extension"
    cp -v COPYING "$1/license/"

    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/nghttp3.$extension" "nghttp3.pkl" \
        "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    [ -d "$build_dir" ] && rm -r "$build_dir"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "nghttp3" "$ARCH" "$VER" \
        "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    [ "$PREBUILT" -eq 1 ] && echo 1 || echo 0
}
