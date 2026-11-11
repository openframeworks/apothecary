#!/usr/bin/env bash
# Open Quantum Safe OpenSSL provider, built against Apothecary OpenSSL.
FORMULA_TYPES=("osx" "linux")
FORMULA_DEPENDS=("openssl" "liboqs")
VER=0.12.0
SOURCE_COMMIT=7e9d095aff7967fab9a8ce693e3da5357dc59d58
SHA256="81b1362af4276cb44afc98213cf0d8caeed8b966130844847163ad3a3b54b18f"
BUILD_ID=1
DEFINES=""
GIT_URL=https://github.com/open-quantum-safe/oqs-provider

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/archive/refs/tags/$VER.tar.gz" || return $?
    verify_sha256 "$VER.tar.gz" "$SHA256" || return $?
    tar -xf "$VER.tar.gz" || return $?
    mv "oqs-provider-$VER" oqsprovider || return $?
    rm "$VER.tar.gz"
}

function prepare() {
    if ! grep -q APOTHECARY_SOURCE_COMMIT oqsprov/CMakeLists.txt; then
        patch -p1 < "$FORMULA_DIR/source-commit.patch" || return $?
    fi
}

function build() {
    local build_dir="$PWD/build_${TYPE}_${PLATFORM}"
    local libdir="lib/$TYPE/$PLATFORM"
    local openssl_root="$LIBS_DIR_REAL/openssl"
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
        *) echoError "Unsupported oqsprovider target: $TYPE"; return 1 ;;
    esac
    [ -f "$openssl_root/$libdir/libcrypto.a" ] || { echoError "Build and copy openssl first"; return 1; }
    [ -f "$LIBS_DIR_REAL/liboqs/$libdir/liboqs.a" ] || { echoError "Build and copy liboqs first"; return 1; }
    local variant static
    for variant in module static; do
        static=OFF
        [ "$variant" != static ] || static=ON
        cmake -S . -B "$build_dir/$variant" "${platform_args[@]}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="$build_dir/Release" \
            -DCMAKE_INSTALL_LIBDIR="$libdir" -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
            -DOQS_PROVIDER_BUILD_STATIC="$static" \
            -DAPOTHECARY_SOURCE_COMMIT="$SOURCE_COMMIT" \
            -DOPENSSL_MODULES_PATH="$libdir/ossl-modules" \
            -DOPENSSL_ROOT_DIR="$openssl_root" -DOPENSSL_USE_STATIC_LIBS=ON \
            -DOPENSSL_INCLUDE_DIR="$openssl_root/include" \
            -DOPENSSL_CRYPTO_LIBRARY="$openssl_root/$libdir/libcrypto.a" \
            -DOPENSSL_SSL_LIBRARY="$openssl_root/$libdir/libssl.a" \
            -DZLIB_LIBRARY="$LIBS_DIR_REAL/zlib/$libdir/zlib.a" \
            -DZLIB_INCLUDE_DIR="$LIBS_DIR_REAL/zlib/include" \
            -Dliboqs_DIR="$LIBS_DIR_REAL/liboqs/$libdir/cmake/liboqs" \
            -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
            -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF || return $?
        cmake --build "$build_dir/$variant" --config Release -j"${PARALLEL_MAKE:-4}" --target install || return $?
    done
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    local libdir="$1/lib/$TYPE/$PLATFORM" module=oqsprovider.so
    [ "$TYPE" != osx ] || module=oqsprovider.dylib
    [ -f "$prefix/lib/$TYPE/$PLATFORM/ossl-modules/$module" ] || return 1
    [ -f "$prefix/lib/$TYPE/$PLATFORM/liboqsprovider.a" ] || return 1
    mkdir -p "$1/include" "$libdir" "$1/license"
    cp -R "$prefix/include/." "$1/include/" || return $?
    cp -R "$prefix/lib/$TYPE/$PLATFORM/." "$libdir/" || return $?
    cp LICENSE.txt "$1/license/" || return $?
    local openssl_version
    openssl_version=$(sed -n 's/^# *define OPENSSL_VERSION_STR *"\([^"]*\)".*/\1/p' "$LIBS_DIR_REAL/openssl/include/openssl/opensslv.h")
    [ -n "$openssl_version" ] || return 1
    mkdir -p "$libdir/cmake"
    sed "s/@OPENSSL_VERSION@/$openssl_version/g" "$FORMULA_DIR/oqsproviderConfig.cmake.in" > "$libdir/cmake/oqsproviderConfig.cmake" || return $?
    # These dependencies are embedded in the module/tools; retain their notices.
    mkdir -p "$1/license/openssl" || return $?
    cp -R "$LIBS_DIR_REAL/openssl/license/." "$1/license/openssl/" || return $?
    mkdir -p "$1/license/liboqs" || return $?
    cp -R "$LIBS_DIR_REAL/liboqs/license/." "$1/license/liboqs/" || return $?
    . "$SECURE_SCRIPT"
    secure "$libdir/liboqsprovider.a" oqsprovider.pkl "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    secure "$libdir/ossl-modules/$module" oqsprovider-module.pkl "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256"
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}
function load() { echo 0; }
