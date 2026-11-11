#!/usr/bin/env bash
# liboqs post-quantum algorithms. Opt-in; not part of the core archive.

FORMULA_TYPES=("osx" "linux")
FORMULA_DEPENDS=()
VER=0.16.0
SHA256="162d5b510518ee5f285f82fa1f16402a885176e818bf1b1a4c3c91c9a2f01eae"
BUILD_ID=2
DEFINES=""
URL="https://github.com/open-quantum-safe/liboqs/archive/refs/tags/${VER}.tar.gz"

GIT_URL="$URL"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$URL" || return $?
    verify_sha256 "${VER}.tar.gz" "$SHA256" || return $?
    tar -xf "${VER}.tar.gz" || return $?
    mv "liboqs-${VER}" liboqs || return $?
    rm "${VER}.tar.gz"
}

function prepare() {
    if ! grep -q OQS_SNTRUP761_crypto_int16_optblocker src/kem/ntruprime/CMakeLists.txt; then
        patch -p1 < "$FORMULA_DIR/sntrup-symbol-namespace.patch" || return $?
    fi
    if ! grep -q OQS_keccak_1600_init_state src/common/CMakeLists.txt; then
        patch -p1 < "$FORMULA_DIR/openssl-sha3-symbol-namespace.patch" || return $?
    fi
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
        *) echoError "Unsupported liboqs target: $TYPE"; return 1 ;;
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
        -DOQS_BUILD_ONLY_LIB=ON -DOQS_DIST_BUILD=ON \
        -DOQS_USE_OPENSSL=OFF -DOQS_LIBJADE_BUILD=OFF \
        -DOQS_USE_CUPQC=OFF -DOQS_USE_ICICLE=OFF || return $?
    cmake --build "$build_dir" --config Release -j"${PARALLEL_MAKE:-4}" --target install
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    local library metadata_name extension=a count=0
    [ "$TYPE" != vs ] || extension=lib
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -R "$prefix/include/." "$1/include/" || return $?
    cp -R "$prefix/lib/$TYPE/$PLATFORM/." "$1/lib/$TYPE/$PLATFORM/" || return $?
    cp LICENSE.txt "$1/license/" || return $?

    # Algorithm implementations carry additional notices in the source tree.
    cp -R docs/algorithms "$1/license/" || return $?
    cp README.md "$1/license/" || return $?
    local notice
    while IFS= read -r notice; do
        mkdir -p "$1/license/$(dirname "$notice")" || return $?
        cp "$notice" "$1/license/$notice" || return $?
    done < <(find src -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \))
    . "$SECURE_SCRIPT"
    for library in "$1/lib/$TYPE/$PLATFORM/"*."$extension"; do
        [ -f "$library" ] || continue
        count=$((count + 1))
        metadata_name=$(basename "$library")
        [ "$TYPE" = vs ] || metadata_name="${metadata_name#lib}"
        secure "$library" "$metadata_name" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    done
    [ "$count" -gt 0 ] || { echoError "No installed liboqs archives for $TYPE/$PLATFORM"; return 1; }
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}

# No remote binary cache until this opt-in formula has published artifacts.
function load() { echo 0; }
