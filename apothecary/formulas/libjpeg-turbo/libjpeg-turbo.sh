#!/usr/bin/env bash
# Static libjpeg-turbo dependency for OpenImageIO. Opt-in; not part of the core archive.

FORMULA_TYPES=("osx" "linux" "vs")
FORMULA_DEPENDS=("zlib")
VER=3.2.1
SHA256="c27ad72a68da151177929aa969ae773a2da5ac2af9ce946079314fdac8cece7f"
BUILD_ID=1
DEFINES=""
URL="https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${VER}/libjpeg-turbo-${VER}.tar.gz"

GIT_URL="$URL"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$URL" || return $?
    verify_sha256 "libjpeg-turbo-${VER}.tar.gz" "$SHA256" || return $?
    tar -xf "libjpeg-turbo-${VER}.tar.gz" || return $?
    mv "libjpeg-turbo-${VER}" libjpeg-turbo || return $?
    rm "libjpeg-turbo-${VER}.tar.gz"
}

function prepare() {
    :
}

function build() {
    local build_dir="$PWD/build_${TYPE}_${PLATFORM}"
    local platform_args=()
    case "$TYPE" in
        osx)
            platform_args=(
                -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
                -DPLATFORM="$PLATFORM" -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
                -DENABLE_BITCODE=OFF -DENABLE_ARC=OFF
            ) ;;
        linux)
            platform_args=(-DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake") ;;
        vs)
            platform_args=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK:-})
            platform_args+=(
                "-DCMAKE_C_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
                "-DCMAKE_CXX_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
            )
            unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
            ;;
        *) echoError "Unsupported libjpeg-turbo target: $TYPE"; return 1 ;;
    esac
    local zlib_library="$LIBS_DIR_REAL/zlib/lib/$TYPE/$PLATFORM/zlib.a"
    [ "$TYPE" != vs ] || zlib_library="$LIBS_DIR_REAL/zlib/lib/$TYPE/$PLATFORM/zlib.lib"
    [ -f "$zlib_library" ] || { echoError "Build and copy zlib first"; return 1; }
    # ARM64EC defines x64 macros too; retain the scalar implementation there.
    local simd=ON
    [ "$PLATFORM" != ARM64EC ] || simd=OFF

    # Install directly into the Apothecary layout. CMake generates exports with
    # the correct relative prefix depth, preserving upstream names and targets.
    cmake -S . -B "$build_dir" "${platform_args[@]}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$build_dir/Release" \
        -DCMAKE_INSTALL_LIBDIR="lib/$TYPE/$PLATFORM" \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
        -DENABLE_SHARED=OFF -DENABLE_STATIC=ON \
        -DWITH_TURBOJPEG=ON -DWITH_TOOLS=OFF -DWITH_TESTS=OFF \
        -DWITH_JNA=OFF -DWITH_SIMD="$simd" \
        -DWITH_SYSTEM_SPNG=OFF -DWITH_SYSTEM_ZLIB=ON \
        -DZLIB_LIBRARY="$zlib_library" -DZLIB_INCLUDE_DIR="$LIBS_DIR_REAL/zlib/include" || return $?
    cmake --build "$build_dir" --config Release -j"${PARALLEL_MAKE:-4}" --target install
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    local library metadata_name extension=a count=0
    [ "$TYPE" != vs ] || extension=lib
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -R "$prefix/include/." "$1/include/" || return $?
    cp -R "$prefix/lib/$TYPE/$PLATFORM/." "$1/lib/$TYPE/$PLATFORM/" || return $?
    cp LICENSE.md "$1/license/" || return $?
    mkdir -p "$1/license/spng" "$1/license/zlib"
    cp src/spng/LICENSE src/spng/libpng-LICENSE.txt "$1/license/spng/" || return $?
    cp src/spng/zlib/LICENSE "$1/license/zlib/" || return $?

    # Upstream exports only *-static when shared libraries are disabled.
    # Provide the conventional targets used by TIFF and OpenImageIO too.
    cat >> "$1/lib/$TYPE/$PLATFORM/cmake/libjpeg-turbo/libjpeg-turboConfig.cmake" <<'CMAKE'
if(NOT TARGET libjpeg-turbo::jpeg AND TARGET libjpeg-turbo::jpeg-static)
    add_library(libjpeg-turbo::jpeg INTERFACE IMPORTED)
    get_target_property(_jpeg_includes libjpeg-turbo::jpeg-static INTERFACE_INCLUDE_DIRECTORIES)
    set_target_properties(libjpeg-turbo::jpeg PROPERTIES
        INTERFACE_LINK_LIBRARIES libjpeg-turbo::jpeg-static
        INTERFACE_INCLUDE_DIRECTORIES "${_jpeg_includes}")
    unset(_jpeg_includes)
endif()
if(NOT TARGET libjpeg-turbo::turbojpeg AND TARGET libjpeg-turbo::turbojpeg-static)
    add_library(libjpeg-turbo::turbojpeg INTERFACE IMPORTED)
    get_target_property(_jpeg_includes libjpeg-turbo::turbojpeg-static INTERFACE_INCLUDE_DIRECTORIES)
    set_target_properties(libjpeg-turbo::turbojpeg PROPERTIES
        INTERFACE_LINK_LIBRARIES libjpeg-turbo::turbojpeg-static
        INTERFACE_INCLUDE_DIRECTORIES "${_jpeg_includes}")
    unset(_jpeg_includes)
endif()
CMAKE
    . "$SECURE_SCRIPT"
    for library in "$1/lib/$TYPE/$PLATFORM/"*."$extension"; do
        [ -f "$library" ] || continue
        count=$((count + 1))
        metadata_name=$(basename "$library")
        [ "$TYPE" = vs ] || metadata_name="${metadata_name#lib}"
        secure "$library" "$metadata_name" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    done
    [ "$count" -gt 0 ] || { echoError "No installed libjpeg-turbo archives for $TYPE/$PLATFORM"; return 1; }
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}

# No remote binary cache until this opt-in formula has published artifacts.
function load() { echo 0; }
