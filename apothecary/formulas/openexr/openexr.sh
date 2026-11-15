#!/usr/bin/env bash
# Static openexr dependency for OpenImageIO. Opt-in; not part of the core archive.

FORMULA_TYPES=("osx" "linux" "vs")
FORMULA_DEPENDS=("imath")
VER=3.5.3
SHA256="ff1de95f4031c1c57c633e647dc97c15282d3aa3bc7fb90745f00f74de4a054f"
BUILD_ID=1
DEFINES=""
URL="https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v${VER}.tar.gz"

GIT_URL="$URL"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$URL" || return $?
    verify_sha256 "v${VER}.tar.gz" "$SHA256" || return $?
    tar -xf "v${VER}.tar.gz" || return $?
    mv "openexr-${VER}" openexr || return $?
    rm "v${VER}.tar.gz"
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
            # Vendored codecs have hand-written x86 kernels; do not advertise
            # ARM64EC until those sources have a native validation pass.
            if [ "$PLATFORM" = ARM64EC ]; then
                echoError "OpenEXR ARM64EC is not supported in this first pass"
                return 1
            fi
            platform_args=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK:-})
            platform_args+=(
                "-DCMAKE_C_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
                "-DCMAKE_CXX_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
            )
            unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
            ;;
        *) echoError "Unsupported openexr target: $TYPE"; return 1 ;;
    esac
    local imath_dir="$LIBS_DIR_REAL/imath/lib/$TYPE/$PLATFORM/cmake/Imath"
    [ -f "$imath_dir/ImathConfig.cmake" ] || { echoError "Build and copy imath first"; return 1; }

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
        -DImath_DIR="$imath_dir" \
        -DCMAKE_REQUIRE_FIND_PACKAGE_Imath=ON \
        -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
        -DOPENEXR_LIB_SUFFIX= \
        -DOPENEXR_BUILD_TOOLS=OFF -DOPENEXR_INSTALL_TOOLS=OFF \
        -DOPENEXR_BUILD_EXAMPLES=OFF -DOPENEXR_BUILD_PYTHON=OFF \
        -DBUILD_WEBSITE=OFF \
        -DOPENEXR_FORCE_INTERNAL_DEFLATE=ON \
        -DOPENEXR_FORCE_INTERNAL_ZSTD=ON \
        -DOPENEXR_FORCE_INTERNAL_OPENJPH=ON \
        -DOPENEXR_USE_TBB=OFF || return $?
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
    # These sources are compiled into OpenEXRCore; retain their notices.
    mkdir -p "$1/license/deflate" "$1/license/zstd" "$1/license/OpenJPH"
    cp external/deflate/COPYING "$1/license/deflate/" || return $?
    cp external/zstd/LICENSE "$1/license/zstd/" || return $?
    cp external/OpenJPH/LICENSE "$1/license/OpenJPH/" || return $?

    . "$SECURE_SCRIPT"
    for library in "$1/lib/$TYPE/$PLATFORM/"*."$extension"; do
        [ -f "$library" ] || continue
        count=$((count + 1))
        metadata_name=$(basename "$library")
        [ "$TYPE" = vs ] || metadata_name="${metadata_name#lib}"
        secure "$library" "$metadata_name" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    done
    [ "$count" -gt 0 ] || { echoError "No installed openexr archives for $TYPE/$PLATFORM"; return 1; }
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}

# No remote binary cache until this opt-in formula has published artifacts.
function load() { echo 0; }
