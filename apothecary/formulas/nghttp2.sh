#!/usr/bin/env bash
#
# nghttp2 - HTTP/2 C library
# https://github.com/nghttp2/nghttp2

FORMULA_TYPES=("vs" "osx" "ios" "xros" "tvos" "catos" "watchos" "android" "linux")
FORMULA_DEPENDS=()

VER=1.70.0
SHA256="aa317e2cf9dca6afa0aed68f8fad6ff303ec6982e25a78c75c0b65e2b9b3ded5"
BUILD_ID=1
DEFINES="-DNGHTTP2_STATICLIB"

GIT_URL=https://github.com/nghttp2/nghttp2
GIT_TAG=v$VER

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/releases/download/v$VER/nghttp2-$VER.tar.gz"
    verify_sha256 "nghttp2-$VER.tar.gz" "$SHA256"
    tar -xf "nghttp2-$VER.tar.gz"
    mv "nghttp2-$VER" nghttp2
    rm -f "nghttp2-$VER.tar.gz"
}

function prepare() {
    if patch --batch --forward -p1 <"$FORMULA_DIR/nghttp2-lib-only.patch"; then
        echo "nghttp2 library-only dependency patch applied"
    elif [ "$(grep -c '^if(NOT ENABLE_LIB_ONLY)' CMakeLists.txt)" -ge 2 ]; then
        echo "nghttp2 library-only dependency patch already applied"
    else
        echo "Failed to apply nghttp2 library-only dependency patch"
        exit 1
    fi
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
        -DCMAKE_C_STANDARD=${C_STANDARD} \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_TESTING=OFF \
        -DENABLE_APP=OFF \
        -DENABLE_DOC=OFF \
        -DENABLE_EXAMPLES=OFF \
        -DENABLE_HPACK_TOOLS=OFF \
        -DENABLE_LIB_ONLY=ON \
        -DENABLE_WERROR=OFF

    cmake --build "$build_dir" --config Release -j"${PARALLEL_MAKE}" --target install
}

function copy() {
    local build_dir="build_${TYPE}_${PLATFORM}/Release"
    local extension=a
    local source_name=libnghttp2.a
    [ "$TYPE" == "vs" ] && extension=lib && source_name=nghttp2.lib
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM"
    cp -Rv "$build_dir/include/"* "$1/include/"
    cp -v "$build_dir/lib/$source_name" "$1/lib/$TYPE/$PLATFORM/nghttp2.$extension"

    . "$SECURE_SCRIPT"
    secure "$1/lib/$TYPE/$PLATFORM/nghttp2.$extension" "nghttp2.pkl" \
        "$VERSION" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}"

    rm -rf "$1/license"
    mkdir -p "$1/license"
    cp -v COPYING "$1/license/"
}

function clean() {
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        rm -r "build_${TYPE}_${PLATFORM}"
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave "$TYPE" "nghttp2" "$ARCH" "$VER" \
        "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" "$BUILD_ID")
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
