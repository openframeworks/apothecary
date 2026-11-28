#!/usr/bin/env bash
# Optional Protocol Buffers C++ runtimes. No protoc is run on the target.
FORMULA_TYPES=("osx" "ios" "tvos" "catos" "xros" "watchos" "vs" "msys2" "linux" "android" "emscripten")
FORMULA_DEPENDS=()
VER=36.2
SHA256="3d9642a662d10e68ebae5e53f14dcce5105684212d5078f8e0d47d1ab3ae6b64"
ABSEIL_VER=20250512.1
ABSEIL_SHA256="9b7a064305e9fd94d124ffa6cc358592eb42b5da588fb4e07d09254aa40086db"
BUILD_ID=1
GIT_URL=https://github.com/protocolbuffers/protobuf
GIT_TAG=v$VER
DEFINES="-Dprotobuf_BUILD_SHARED_LIBS=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_BUILD_LIBUPB=OFF -Dprotobuf_WITH_ZLIB=OFF abseil=$ABSEIL_VER abseilSHA256=$ABSEIL_SHA256"

function download() {
    . "$DOWNLOADER_SCRIPT"
    curl --fail --location --retry 3 -o "protobuf-$VER.tar.gz" "$GIT_URL/releases/download/v$VER/protobuf-$VER.tar.gz" || return 1
    verify_sha256 "protobuf-$VER.tar.gz" "$SHA256" || return 1
    curl --fail --location --retry 3 -o "abseil-$ABSEIL_VER.tar.gz" "https://github.com/abseil/abseil-cpp/archive/refs/tags/$ABSEIL_VER.tar.gz" || return 1
    verify_sha256 "abseil-$ABSEIL_VER.tar.gz" "$ABSEIL_SHA256" || return 1
    mkdir -p protobuf/third_party/abseil-cpp || return 1
    tar -xf "protobuf-$VER.tar.gz" -C protobuf --strip-components=1 || return 1
    tar -xf "abseil-$ABSEIL_VER.tar.gz" -C protobuf/third_party/abseil-cpp --strip-components=1 || return 1
    rm "protobuf-$VER.tar.gz" "abseil-$ABSEIL_VER.tar.gz"
}

function prepare() { :; }

function _protobuf_cmake_path() {
    if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" args=() configs=(Release) config crt=OFF memory64=0
    local prefix abseil
    prefix=$(_protobuf_cmake_path "$(pwd)/$bdir/Release")
    abseil=$(_protobuf_cmake_path "$(pwd)/third_party/abseil-cpp")
    case "$TYPE" in
        osx|ios|tvos|catos|xros|watchos)
            args+=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
                -DPLATFORM="$PLATFORM" -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
                -DENABLE_BITCODE=OFF -DENABLE_ARC=OFF
                -DCMAKE_C_FLAGS="${FLAG_RELEASE:-}" -DCMAKE_CXX_FLAGS="${FLAG_RELEASE:-}")
            ;;
        vs)
            # Both Protobuf and Abseil must use the engine's selected CRT.
            [ "${MT_TYPE_CASE:-md}" != mt ] || crt=ON
            export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:+${MSYS2_ARG_CONV_EXCL};}-DCMAKE_C_FLAGS_;-DCMAKE_CXX_FLAGS_"
            args+=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK:-}
                -DCMAKE_C_FLAGS_RELEASE="${VS_C_FLAGS:-} ${FLAGS_RELEASE:-}"
                -DCMAKE_CXX_FLAGS_RELEASE="${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
                -DCMAKE_C_FLAGS_DEBUG="${VS_C_FLAGS:-} ${FLAGS_DEBUG:-}"
                -DCMAKE_CXX_FLAGS_DEBUG="${VS_C_FLAGS:-} ${FLAGS_DEBUG:-} ${EXCEPTION_FLAGS:-}")
            ;;
        msys2) args+=(-G Ninja -DCMAKE_C_FLAGS="${FLAG_RELEASE:-}" -DCMAKE_CXX_FLAGS="${FLAG_RELEASE:-}") ;;
        linux)
            if [ "${CROSSCOMPILING:-0}" = 1 ]; then
                . "$APOTHECARY_DIR/configure/linux${PLATFORM}_configure.sh" "$ABI" || return 1
            fi
            args+=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake"
                -DGCC_VERSION="${GCC_VERSION:-10}" -DCPP_STANDARD="${CPP_STANDARD:-17}"
                -DCMAKE_C_FLAGS="${FLAG_RELEASE:-} ${CFLAGS:-}" -DCMAKE_CXX_FLAGS="${FLAG_RELEASE:-} ${CXXFLAGS:-}")
            ;;
        android)
            . "$APOTHECARY_DIR/configure/android_configure.sh" "$ABI" cmake || return 1
            args+=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/android.toolchain.cmake"
                -DANDROID_ABI="$ABI" -DANDROID_API="$ANDROID_API" -DANDROID_PLATFORM="$ANDROID_PLATFORM"
                -DANDROID_NDK_ROOT="$ANDROID_NDK_ROOT"
                -DCMAKE_C_FLAGS="${FLAG_RELEASE:-}" -DCMAKE_CXX_FLAGS="${FLAG_RELEASE:-}")
            ;;
        emscripten)
            [ "$ARCH" != 64 ] || memory64=1
            args+=(-G Ninja -DCMAKE_TOOLCHAIN_FILE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
                -DCMAKE_C_FLAGS="${FLAG_RELEASE:-} -sMEMORY64=$memory64"
                -DCMAKE_CXX_FLAGS="${FLAG_RELEASE:-} -sMEMORY64=$memory64")
            ;;
        *) echo "Unsupported Protobuf target: $TYPE" >&2; return 1 ;;
    esac
    # Resolve Abseil only from the verified source archive, never from the host
    # package registry or an unverified FetchContent download during configure.
    cmake -S . -B "$bdir" "${args[@]}" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix" \
        -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_CXX_STANDARD="${CPP_STANDARD:-17}" -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_SHARED_LIBS=OFF -Dprotobuf_BUILD_SHARED_LIBS=OFF \
        -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF -Dprotobuf_BUILD_EXAMPLES=OFF \
        -Dprotobuf_BUILD_PROTOC_BINARIES=OFF -Dprotobuf_BUILD_LIBPROTOC=OFF -Dprotobuf_BUILD_LIBUPB=OFF \
        -Dprotobuf_WITH_ZLIB=OFF -Dprotobuf_INSTALL=ON -Dprotobuf_MSVC_STATIC_RUNTIME="$crt" \
        -Dprotobuf_FORCE_FETCH_DEPENDENCIES=ON -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
        -DFETCHCONTENT_SOURCE_DIR_ABSL="$abseil" -DABSL_ENABLE_INSTALL=ON -DABSL_PROPAGATE_CXX_STD=ON || return 1
    [ "$TYPE" != vs ] || configs+=(Debug)
    for config in "${configs[@]}"; do
        cmake --build "$bdir" --config "$config" --target install --parallel "${PARALLEL_MAKE:-2}" || return 1
    done
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release" libdir="$1/lib/$TYPE/$PLATFORM"
    local file name binary extension=a
    [ "$TYPE" != vs ] || extension=lib
    [ -f "$prefix/lib/libprotobuf.$extension" ] && [ -f "$prefix/lib/libprotobuf-lite.$extension" ] || return 1
    mkdir -p "$libdir" "$1/include" "$1/license" || return 1
    # Keep the complete upstream SDK layout: its CMake targets carry all Abseil
    # and utf8_range dependencies. Full and lite runtimes are alternatives.
    cp -R "$prefix/." "$libdir/" || return 1
    cp -R "$prefix/include/." "$1/include/" || return 1
    cp LICENSE "$1/license/protobuf-LICENSE" || return 1
    cp third_party/abseil-cpp/LICENSE "$1/license/abseil-LICENSE" || return 1
    cp third_party/utf8_range/LICENSE "$1/license/utf8_range-LICENSE" || return 1
    for file in "$libdir/lib/pkgconfig/"*.pc; do
        [ -f "$file" ] || continue
        sed -e 's|^prefix=.*|prefix=${pcfiledir}/../..|' \
            -e 's|^exec_prefix=.*|exec_prefix=${prefix}|' \
            -e 's|^libdir=.*|libdir=${prefix}/lib|' \
            -e 's|^includedir=.*|includedir=${prefix}/include|' "$file" > "$file.tmp" || return 1
        mv "$file.tmp" "$file" || return 1
    done
    . "$SECURE_SCRIPT"
    for name in protobuf protobuf-lite; do
        binary="lib$name.$extension"
        secure "$libdir/lib/$binary" "$name.pkl" "$VER" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256" || return 1
        if [ "$TYPE" = vs ]; then
            secure "$libdir/lib/lib${name}d.lib" "${name}d.pkl" "$VER" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256" || return 1
        fi
    done
}

function clean() { cmake --build "build_${TYPE}_${PLATFORM}" --target clean; }
function load() {
    . "$LOAD_SCRIPT"
    loadsave "$TYPE" protobuf "$ARCH" "$VER" "$LIBS_DIR_REAL/protobuf/lib/$TYPE/$PLATFORM/lib" "$BUILD_ID" | tail -n 1
}
