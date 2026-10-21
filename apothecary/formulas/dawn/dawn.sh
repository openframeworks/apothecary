#!/usr/bin/env bash
#
# Dawn — WebGPU implementation (Tint + native backends)
# https://dawn.googlesource.com/dawn
#
# Modelled on ofWorks/ofLibs dawn/chalet.yaml (commit cd2d5a667d11):
#   cmake -DDAWN_ENABLE_INSTALL=ON
#         -DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC
#         -DDAWN_FETCH_DEPENDENCIES=ON
#         -DTINT_BUILD_SPV_READER=ON
#         -DBUILD_SHARED_LIBS=OFF
# Apple:  DAWN_ENABLE_METAL=ON  DAWN_ENABLE_VULKAN=OFF
# Linux:  DAWN_ENABLE_VULKAN=ON
# VS:     DAWN_ENABLE_D3D12=ON
#
# DAWN_BUILD_MONOLITHIC_LIBRARY=ON is invalid on this SHA (STATIC|SHARED|OFF).
# depot_tools is vendored onto PATH; deps are fetched by DAWN_FETCH_DEPENDENCIES.

FORMULA_TYPES=("osx" "ios" "tvos" "xros" "catos" "linux" "vs")
# watchos: WatchOS.sdk has no Metal.framework — Dawn cannot target it.
FORMULA_DEPENDS=()

VER=2026.07.31
SOURCE_COMMIT=cd2d5a667d1140af6e89f4c4c24f6545e1d5d2d7
BUILD_ID=7
DEFINES=""

GIT_URL=https://github.com/google/dawn.git
GIT_URL_FALLBACK=https://dawn.googlesource.com/dawn
GIT_TAG=$SOURCE_COMMIT

DEPOT_TOOLS_URL=https://chromium.googlesource.com/chromium/tools/depot_tools.git

# download the source code and unpack it into LIB_NAME
function _dawn_retry_git() {
    local attempt
    for attempt in 1 2 3; do
        if git "$@"; then return 0; fi
        if [ "$attempt" -lt 3 ]; then sleep "$attempt"; fi
    done
    return 1
}

function _dawn_patch_fetcher() {
    if ! grep -q '^def run_git(' tools/fetch_dawn_dependencies.py; then
        patch -p1 < "$APOTHECARY_DIR/formulas/dawn/reliable-dependency-fetch.patch" || return 1
    fi
}

function download() {
    . "$DOWNLOADER_SCRIPT"

    if [ -d dawn ]; then
        rm -rf dawn
    fi

    mkdir -p dawn
    git -C dawn init
    if ! git -C dawn remote add origin "${GIT_URL}"; then
        echoWarning "dawn: remote add failed (already set?)"
    fi
    if ! _dawn_retry_git -C dawn fetch --depth=1 origin "${SOURCE_COMMIT}"; then
        echoWarning "Dawn GitHub fetch failed; trying ${GIT_URL_FALLBACK}"
        git -C dawn remote set-url origin "${GIT_URL_FALLBACK}"
        _dawn_retry_git -C dawn fetch --depth=1 origin "${SOURCE_COMMIT}"
    fi
    git -C dawn checkout --force FETCH_HEAD
    verify_git_commit dawn "${SOURCE_COMMIT}"
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echoVerbose "prepare dawn @ $(pwd)"
    _dawn_patch_fetcher || return 1

    # Vendored depot_tools (PR #533 / user request). Fetch itself is CMake
    # DAWN_FETCH_DEPENDENCIES — ofLibs proved that path; we do not run gn/ninja.
    local vendor
    vendor="$(pwd)/.vendor"
    mkdir -p "${vendor}"
    if [ ! -d "${vendor}/depot_tools/.git" ]; then
        echo "Cloning depot_tools into ${vendor}/depot_tools"
        _dawn_retry_git clone --depth=1 "${DEPOT_TOOLS_URL}" "${vendor}/depot_tools" || return 1
    fi
    export PATH="${vendor}/depot_tools:${PATH}"
    export DEPOT_TOOLS_UPDATE=0
    export DEPOT_TOOLS_WIN_TOOLCHAIN=0

    # gcc-10 libstdc++ has no std::atomic::wait / notify_all (GCC 11).
    if [ "$TYPE" = "linux" ]; then
        # GCC 10 cannot deduce this aggregate visitor's template arguments.
        local visitor=src/tint/lang/core/ir/transform/multiplanar_external_texture.cc
        if ! grep -q 'overloaded(Ts...) -> overloaded<Ts...>;' "$visitor"; then
            patch -p1 < "$APOTHECARY_DIR/formulas/dawn/gcc10-visitor-deduction.patch" || return 1
        fi
        local p
        p="${APOTHECARY_DIR}/formulas/dawn/gcc10-atomic-wait.patch"
        if [ -f "$p" ] && ! grep -q "mCompletedCv" src/dawn/platform/WorkerThread.h 2>/dev/null; then
            echo "dawn: applying gcc-10 atomic wait polyfill"
            patch -p1 < "$p"
        fi
    fi
}

function _dawn_backend_defs() {
    # Shared trim: no samples/tests/tools/protobuf/wire/null/GLFW.
    # Space-separated so unquoted ${DEFS} word-splits into cmake args.
    local common
    common="-DDAWN_ENABLE_INSTALL=ON -DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC -DDAWN_FETCH_DEPENDENCIES=ON -DTINT_ENABLE_INSTALL=OFF -DTINT_BUILD_SPV_READER=ON -DTINT_BUILD_TESTS=OFF -DTINT_BUILD_CMD_TOOLS=OFF -DTINT_BUILD_FUZZER=OFF -DDAWN_BUILD_SAMPLES=OFF -DDAWN_BUILD_TESTS=OFF -DDAWN_BUILD_PROTOBUF=OFF -DDAWN_ENABLE_WIRE=OFF -DDAWN_ENABLE_NULL=OFF -DDAWN_USE_GLFW=OFF -DDAWN_ENABLE_D3D11=OFF -DDAWN_ENABLE_DESKTOP_GL=OFF -DDAWN_ENABLE_OPENGLES=OFF -DBUILD_SHARED_LIBS=OFF"

    case "$TYPE" in
        osx)
            echo "${common} -DDAWN_ENABLE_METAL=ON -DDAWN_ENABLE_VULKAN=OFF -DDAWN_ENABLE_D3D12=OFF -DDAWN_TARGET_MACOS=ON"
            ;;
        ios|tvos|xros)
            echo "${common} -DDAWN_ENABLE_METAL=ON -DDAWN_ENABLE_VULKAN=OFF -DDAWN_ENABLE_D3D12=OFF -DDAWN_TARGET_MACOS=OFF"
            ;;
        catos)
            # Catalyst compiles as iOS-macabi but Metal feature sets are macOS.
            echo "${common} -DDAWN_ENABLE_METAL=ON -DDAWN_ENABLE_VULKAN=OFF -DDAWN_ENABLE_D3D12=OFF -DDAWN_TARGET_MACOS=ON"
            ;;
        linux)
            echo "${common} -DDAWN_ENABLE_METAL=OFF -DDAWN_ENABLE_VULKAN=ON -DDAWN_ENABLE_D3D12=OFF -DDAWN_USE_X11=ON -DDAWN_USE_WAYLAND=OFF -DDAWN_SUPPORTS_CXX_MODULES=OFF"
            ;;
        vs)
            echo "${common} -DDAWN_ENABLE_METAL=OFF -DDAWN_ENABLE_VULKAN=OFF -DDAWN_ENABLE_D3D12=ON -DDAWN_FORCE_SYSTEM_COMPONENT_LOAD=ON -DDAWN_USE_BUILT_DXC=OFF -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DABSL_MSVC_STATIC_RUNTIME=ON"
            ;;
        *)
            echo "${common}"
            ;;
    esac
}

function _dawn_cxx_standard() {
    # Dawn Math.cpp uses std::bit_cast (C++20). Linux CI gcc-10 defaults to 17.
    local std="${CPP_STANDARD:-17}"
    case "${std}" in
        11|14|17) echo 20 ;;
        *) echo "${std}" ;;
    esac
}

function _dawn_deploy_target() {
    case "$TYPE" in
        osx) echo "11.0" ;;
        catos) echo "16.0" ;; # iOS GPUFamily MTLFeatureSet is unavailable on Catalyst below 16
        *) echo "${MIN_SDK_VER}" ;;
    esac
}

function _lipo_ios_simulator() {
    local dest="$1"
    local name="$2"
    local arm64="${dest}/lib/ios/SIMULATORARM64/${name}"
    local x64="${dest}/lib/ios/SIMULATOR64/${name}"
    local fatdir="${dest}/lib/ios/iphonesimulator"
    if [[ -f "${arm64}" && -f "${x64}" ]]; then
        mkdir -p "${fatdir}"
        echo "lipo iOS simulator ${name} (arm64 + x86_64)"
        lipo -create "${arm64}" "${x64}" -output "${fatdir}/${name}"
        lipo -info "${fatdir}/${name}"
    fi
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath "$LIBS_DIR")
    CORE_DIR=$(pwd)
    _dawn_patch_fetcher || return 1

    # `apo build` does not run prepareFormula. Vendor depot_tools if needed.
    if [ ! -d "${CORE_DIR}/.vendor/depot_tools" ]; then
        prepare
    fi
    if [ -d "${CORE_DIR}/.vendor/depot_tools" ]; then
        export PATH="${CORE_DIR}/.vendor/depot_tools:${PATH}"
        export DEPOT_TOOLS_UPDATE=0
        export DEPOT_TOOLS_WIN_TOOLCHAIN=0
    fi

    local BACKEND
    BACKEND="$(_dawn_backend_defs)"
    DEFINES="${BACKEND}"

    local DEFS
    DEFS="
        -DCMAKE_C_STANDARD=${C_STANDARD} \
        -DCMAKE_CXX_STANDARD=$(_dawn_cxx_standard) \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
        ${BACKEND}"

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        echoVerbose "building dawn [$TYPE] PLATFORM:[$PLATFORM] MIN_SDK_VER:[$MIN_SDK_VER]"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        # Dawn WorkerThread uses std::atomic::wait (macOS 11 / iOS 14 / watchOS 7+).
        local DAWN_DEPLOY
        DAWN_DEPLOY="$(_dawn_deploy_target)"

        cmake .. ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DDEPLOYMENT_TARGET=${DAWN_DEPLOY} \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=${DAWN_DEPLOY} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -g0 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -g0 ${FLAG_RELEASE}" \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=OFF \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "${CORE_DIR}"

    elif [ "$TYPE" == "vs" ]; then
        echoVerbose "building dawn $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.lib *.o
        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "${CORE_DIR}"

    elif [ "$TYPE" == "linux" ]; then
        if [ "${CROSSCOMPILING:-0}" -eq 1 ]; then
            source "$APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh"
        fi
        echoVerbose "building dawn [$TYPE] PLATFORM:[${PLATFORM:-$ARCH}] CXX=$(_dawn_cxx_standard)"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        local polyfill
        polyfill="${APOTHECARY_DIR}/formulas/dawn/bit_cast_polyfill.h"
        cmake .. ${DEFS} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -g0 -include ${polyfill} ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -g0 ${FLAG_RELEASE}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "${CORE_DIR}"
    else
        echoError "dawn: unsupported TYPE=$TYPE"
        exit 1
    fi
}

function _install_prefix() {
    if [ "$TYPE" == "vs" ]; then
        echo "build_${TYPE}_${PLATFORM}/Release"
    elif [ "$TYPE" == "android" ]; then
        echo "build_${TYPE}_${ABI}/Release"
    else
        echo "build_${TYPE}_${PLATFORM}/Release"
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    echo "copy dawn -> $1"
    mkdir -p "$1/include"
    . "$SECURE_SCRIPT"

    local prefix
    prefix="$(_install_prefix)"

    if [ -d "${prefix}/include" ]; then
        cp -R "${prefix}/include/." "$1/include/"
    else
        echoWarning "dawn: ${prefix}/include missing"
    fi

    mkdir -p "$1/lib/$TYPE/$PLATFORM/"

    local copied=0
    local f
    if [ "$TYPE" == "vs" ]; then
        for f in "${prefix}/lib/"*.lib "${prefix}/lib/"*.a; do
            [ -f "$f" ] || continue
            cp -v "$f" "$1/lib/$TYPE/$PLATFORM/"
            copied=1
        done
        if [ -f "$1/lib/$TYPE/$PLATFORM/webgpu_dawn.lib" ]; then
            secure "$1/lib/$TYPE/$PLATFORM/webgpu_dawn.lib" "dawn.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        elif [ -f "$1/lib/$TYPE/$PLATFORM/libwebgpu_dawn.a" ]; then
            secure "$1/lib/$TYPE/$PLATFORM/libwebgpu_dawn.a" "dawn.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        fi
    else
        for f in "${prefix}/lib/"libdawn*.a "${prefix}/lib/"libwebgpu_dawn.a "${prefix}/lib/"*.a; do
            [ -f "$f" ] || continue
            cp -v "$f" "$1/lib/$TYPE/$PLATFORM/"
            copied=1
        done
        if [ -f "$1/lib/$TYPE/$PLATFORM/libwebgpu_dawn.a" ]; then
            secure "$1/lib/$TYPE/$PLATFORM/libwebgpu_dawn.a" "dawn.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        elif compgen -G "$1/lib/$TYPE/$PLATFORM/libdawn*.a" > /dev/null; then
            local first
            first="$(ls "$1/lib/$TYPE/$PLATFORM"/libdawn*.a | head -n 1)"
            secure "$first" "dawn.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        fi
        if [[ "$TYPE" == "ios" ]]; then
            if [ -f "$1/lib/$TYPE/$PLATFORM/libwebgpu_dawn.a" ]; then
                _lipo_ios_simulator "$1" "libwebgpu_dawn.a"
            fi
        fi
    fi

    if [ "$copied" -eq 0 ]; then
        echoError "dawn: no installed library under ${prefix}/lib"
        ls -la "${prefix}/lib" 2>/dev/null || true
        exit 1
    fi

    if [ -d "$1/license" ]; then
        rm -rf "$1/license"
    fi
    mkdir -p "$1/license"
    if [ -f LICENSE ]; then
        cp -v LICENSE "$1/license/"
    fi
}

function clean() {
    if [ "$TYPE" == "vs" ]; then
        rm -rf "build_${TYPE}_${PLATFORM}"
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux)$ ]]; then
        rm -rf "build_${TYPE}_${PLATFORM}"
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "dawn" ${ARCH} ${VER} "$LIBS_DIR_REAL/dawn/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        TARGET_DIR="$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM"
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        else
            echoInfo "Folder does not exist: $TARGET_DIR"
        fi
        echo 0
    fi
}
