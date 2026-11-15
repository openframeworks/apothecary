#!/usr/bin/env bash
# Static imath dependency for OpenImageIO. Opt-in; not part of the core archive.

FORMULA_TYPES=("osx" "linux" "vs")
FORMULA_DEPENDS=()
VER=3.2.3
SHA256="e10c12b3f21f45bf08e09d4215d9c7691368d747beebd840de0b6fefed2df9f8"
BUILD_ID=1
DEFINES=""
URL="https://github.com/AcademySoftwareFoundation/Imath/archive/refs/tags/v${VER}.tar.gz"

GIT_URL="$URL"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$URL" || return $?
    verify_sha256 "v${VER}.tar.gz" "$SHA256" || return $?
    tar -xf "v${VER}.tar.gz" || return $?
    mv "Imath-${VER}" imath || return $?
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
            platform_args=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK:-})
            platform_args+=(
                "-DCMAKE_C_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
                "-DCMAKE_CXX_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
            )
            unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
            ;;
        *) echoError "Unsupported imath target: $TYPE"; return 1 ;;
    esac

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
        -DIMATH_LIB_SUFFIX= \
        -DIMATH_BUILD_APPLE_FRAMEWORKS=OFF \
        -DPYTHON=OFF -DPYBIND11=OFF -DBUILD_WEBSITE=OFF || return $?
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

    . "$SECURE_SCRIPT"
    for library in "$1/lib/$TYPE/$PLATFORM/"*."$extension"; do
        [ -f "$library" ] || continue
        count=$((count + 1))
        metadata_name=$(basename "$library")
        [ "$TYPE" = vs ] || metadata_name="${metadata_name#lib}"
        secure "$library" "$metadata_name" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    done
    [ "$count" -gt 0 ] || { echoError "No installed imath archives for $TYPE/$PLATFORM"; return 1; }
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}

# No remote binary cache until this opt-in formula has published artifacts.
function load() { echo 0; }
