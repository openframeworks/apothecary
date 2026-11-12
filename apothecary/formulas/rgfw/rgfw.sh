#!/usr/bin/env bash
# Optional RGFW windowing library. Upstream has no mobile Apple/Android backend.
FORMULA_TYPES=("osx" "vs" "msys2" "linux" "emscripten")
FORMULA_DEPENDS=()
VER=1.8.1
BUILD_ID=2
SHA256="39f9dc8f89e86926fe2be4ffd6cdc877c1e7d179e24e3c803389ece50d6aef60"
GIT_URL=https://github.com/ColleagueRiley/RGFW
GIT_TAG=$VER
DEFINES="-DRGFW_OPENGL -DRGFWDEF=extern -DBUILD_SHARED_LIBS=OFF"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "${GIT_URL}/archive/refs/tags/${VER}.tar.gz"
    verify_sha256 "${VER}.tar.gz" "$SHA256" || return 1
    mkdir -p rgfw
    tar -xf "${VER}.tar.gz" -C rgfw --strip-components=1 || return 1
    rm "${VER}.tar.gz"
}

function prepare() {
    cp "$FORMULA_DIR/CMakeLists.txt" "$FORMULA_DIR/rgfw.c" "$FORMULA_DIR/rgfw_apothecary.h" .
}

function build() {
    local bdir="build_${TYPE}_${PLATFORM}" args=()
    args+=(-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(pwd)/$bdir/Release" -DCMAKE_C_STANDARD="${C_STANDARD:-17}")
    case "$TYPE" in
        osx)
            args+=(-DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
                -DPLATFORM="$PLATFORM" -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
                -DENABLE_BITCODE=OFF -DENABLE_ARC=OFF -DCMAKE_C_FLAGS="${FLAG_RELEASE:-}")
            ;;
        vs)
            # Keep slash-prefixed MSVC flags as flags, rather than MSYS paths.
            export MSYS2_ARG_CONV_EXCL="${MSYS2_ARG_CONV_EXCL:+${MSYS2_ARG_CONV_EXCL};}-DCMAKE_C_FLAGS_RELEASE="
            args+=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM"
                -DCMAKE_C_FLAGS_RELEASE="${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}")
            ;;
        msys2) args+=(-G Ninja -DCMAKE_C_FLAGS="${FLAG_RELEASE:-}") ;;
        linux)
            if [ "${CROSSCOMPILING:-0}" = 1 ]; then
                . "$APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh" "$ABI"
            fi
            args+=(-DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake"
                -DGCC_VERSION="${GCC_VERSION:-10}" -DCMAKE_C_FLAGS="${FLAG_RELEASE:-} ${CFLAGS:-}")
            ;;
        emscripten)
            local memory64=0
            [ "$ARCH" != 64 ] || memory64=1
            args+=(-DCMAKE_TOOLCHAIN_FILE="$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake"
                -DCMAKE_C_FLAGS="${FLAG_RELEASE:-} -sMEMORY64=$memory64")
            ;;
        *) echo "RGFW has no backend for TYPE=$TYPE" >&2; return 1 ;;
    esac
    cmake -S . -B "$bdir" "${args[@]}" || return 1
    cmake --build "$bdir" --config Release --target install --parallel "${PARALLEL_MAKE:-2}"
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release" rgfw_binary=librgfw.a
    [ "$TYPE" != vs ] || rgfw_binary=rgfw.lib
    local libdir="$1/lib/$TYPE/$PLATFORM"
    mkdir -p "$1/include" "$1/license" "$libdir/cmake" "$libdir/pkgconfig"
    cp "$prefix/include/"*.h "$1/include/" || return 1
    cp "$prefix/license/LICENSE" "$1/license/" || return 1
    cp "$prefix/lib/$rgfw_binary" "$libdir/$rgfw_binary" || return 1
    cp "$FORMULA_DIR/rgfwConfig.cmake" "$libdir/cmake/rgfwConfig.cmake"
    local private_libs=""
    case "$TYPE" in
        osx) private_libs="-framework Cocoa -framework OpenGL -framework IOKit -framework CoreVideo" ;;
        vs|msys2) private_libs="-lopengl32 -lgdi32 -luser32 -lshell32" ;;
        linux) private_libs="-lX11 -lXrandr -lXcursor -lXi -lXext -lGL -ldl -lpthread -lm" ;;
    esac
    sed -e "s/@VERSION@/$VER/g" -e "s/@PRIVATE_LIBS@/$private_libs/g" \
        "$FORMULA_DIR/rgfw.pc.in" > "$libdir/pkgconfig/rgfw.pc"
    local CXX
    CXX=$(sed -n 's/^set(CMAKE_C_COMPILER "\([^"]*\)")/\1/p' \
        build_${TYPE}_${PLATFORM}/CMakeFiles/*/CMakeCCompiler.cmake | head -n 1)
    . "$SECURE_SCRIPT"
    secure "$libdir/$rgfw_binary" rgfw.pkl "$VER" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256"
}

function clean() { cmake --build "build_${TYPE}_${PLATFORM}" --target clean; }
function load() {
    . "$LOAD_SCRIPT"
    loadsave "$TYPE" rgfw "$ARCH" "$VER" "$LIBS_DIR_REAL/rgfw/lib/$TYPE/$PLATFORM" "$BUILD_ID" | tail -n 1
}
