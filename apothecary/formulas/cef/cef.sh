#!/usr/bin/env bash
#
# CEF — Chromium Embedded Framework
# Desktop binary distributions from Spotify's CEF CDN. These already contain
# Chromium, public headers and libcef_dll_wrapper source. Apothecary compiles
# the C++ wrapper with openFrameworks-compatible runtime settings and packages
# the runtime, resources, locales and licences next to it.
# https://github.com/chromiumembedded/cef#binary-distributions
# https://cef-builds.spotifycdn.com/index.html
#
# Official binaries exist for osx, linux and vs (x86_64 and arm64). There is
# no iOS, Android, Emscripten, MSYS2 or ARM64EC distribution.

FORMULA_TYPES=("osx" "linux" "vs")
FORMULA_DEPENDS=()

# Spotify "Current Stable" 156.0.15, Chromium 156.0.8078.80 (2026-10-31).
VER=156.0.15
CEF_BUILD="156.0.15+gcf671c0+chromium-156.0.8078.80"
CEF_CDN="https://cef-builds.spotifycdn.com"
BUILD_ID=1
DEFINES="-DUSE_SANDBOX=OFF -DCEF_RUNTIME_LIBRARY_FLAG=/MD"

SHA256_LINUX64="1d0a26b3ce480d8db220e9af0f7c8699afa889e088eb5f7f7d822bbac1c9920f"
SHA256_LINUXARM64="932afa461d8117dfa191b203c8a95cf6885827b3f2111ddc55489f96e94baedd"
SHA256_MACOSARM64="938081b5bb552b4990b9667662d9909429d2c113d862c83826322310835666f9"
SHA256_MACOSX64="db77f7460ba172a9b2361894c4da062ac88e4f7346e319649217e891eedb4f68"
SHA256_WINDOWS64="51fabb69de6bbb99b38704665e8bc67a511ec4a68f8cfa2465460c03ae7e8d75"
SHA256_WINDOWSARM64="59a4b4e3176e0893f6fae130ae5659d9e0df1a36024f21d3512de2d4b063146c"

GIT_URL=https://github.com/chromiumembedded/cef

function _cef_platform() {
    case "$TYPE" in
        osx | macos)
            case "$ARCH" in
                arm64) printf '%s\n' macosarm64 ;;
                x86_64) printf '%s\n' macosx64 ;;
                *)
                    echoError "CEF has no binary distribution for TYPE=$TYPE ARCH=$ARCH"
                    return 1
                    ;;
            esac
            ;;
        linux)
            case "$ARCH" in
                64 | x86_64) printf '%s\n' linux64 ;;
                arm64 | aarch64) printf '%s\n' linuxarm64 ;;
                *)
                    echoError "CEF has no binary distribution for TYPE=linux ARCH=$ARCH"
                    return 1
                    ;;
            esac
            ;;
        vs)
            case "$ARCH" in
                64) printf '%s\n' windows64 ;;
                arm64) printf '%s\n' windowsarm64 ;;
                *)
                    echoError "CEF has no binary distribution for TYPE=vs ARCH=$ARCH"
                    return 1
                    ;;
            esac
            ;;
        *)
            echoError "CEF binary distributions are desktop-only (osx, linux, vs)"
            return 1
            ;;
    esac
}

function _cef_sha256() {
    case "$1" in
        linux64) printf '%s\n' "$SHA256_LINUX64" ;;
        linuxarm64) printf '%s\n' "$SHA256_LINUXARM64" ;;
        macosarm64) printf '%s\n' "$SHA256_MACOSARM64" ;;
        macosx64) printf '%s\n' "$SHA256_MACOSX64" ;;
        windows64) printf '%s\n' "$SHA256_WINDOWS64" ;;
        windowsarm64) printf '%s\n' "$SHA256_WINDOWSARM64" ;;
        *)
            echoError "No SHA-256 is recorded for CEF platform $1"
            return 1
            ;;
    esac
}

function _cef_archive_name() {
    printf 'cef_binary_%s_%s.tar.bz2\n' "$CEF_BUILD" "$1"
}

function _cef_url() {
    local name
    name="$(_cef_archive_name "$1")"
    printf '%s/%s\n' "$CEF_CDN" "${name//+/%2B}"
}

function _cef_project_arch() {
    case "$1" in
        macosarm64 | linuxarm64 | windowsarm64) printf '%s\n' arm64 ;;
        *) printf '%s\n' x86_64 ;;
    esac
}

function _cef_build_dir() {
    if [ "$TYPE" = "vs" ]; then
        printf 'build_%s_%s\n' "$TYPE" "$ARCH"
    else
        printf 'build_%s_%s\n' "$TYPE" "${PLATFORM:-$ARCH}"
    fi
}

function _cef_write_wrapper_cmake() {
    cat <<'EOF'
# Apothecary wrapper-only bootstrap. The SDK CMakeLists.txt also configures
# cefclient/cefsimple, which pull GTK on Linux and sample apps on every
# desktop target. We only compile libcef_dll_wrapper.
cmake_minimum_required(VERSION 3.21)
project(cef_dll_wrapper_only)
set(CEF_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)
add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)
EOF
}

function download() {
    local platform archive url sha extract encoded
    platform="$(_cef_platform)" || return 1
    archive="$(_cef_archive_name "$platform")"
    encoded="${archive//+/%2B}"
    url="$(_cef_url "$platform")"
    sha="$(_cef_sha256 "$platform")" || return 1
    . "$DOWNLOADER_SCRIPT"
    downloader "$url"
    if [ ! -f "$archive" ] && [ -f "$encoded" ]; then
        mv "$encoded" "$archive"
    fi
    verify_sha256 "$archive" "$sha"
    tar -xjf "$archive"
    extract="cef_binary_${CEF_BUILD}_${platform}"
    if [ ! -d "$extract" ]; then
        echoError "CEF archive did not contain $extract"
        return 1
    fi
    rm -rf cef
    mv "$extract" cef
    rm -f "$archive"
}

function prepare() {
    if [ ! -f CMakeLists.txt.sdk ]; then
        if [ ! -f CMakeLists.txt ]; then
            echoError "CEF SDK CMakeLists.txt is missing"
            return 1
        fi
        mv CMakeLists.txt CMakeLists.txt.sdk
    fi
    _cef_write_wrapper_cmake > CMakeLists.txt
}

function build() {
    local platform project_arch build_dir generator
    platform="$(_cef_platform)" || return 1
    project_arch="$(_cef_project_arch "$platform")"
    build_dir="$(_cef_build_dir)"
    mkdir -p "$build_dir"
    rm -f "$build_dir/CMakeCache.txt"

    if [ "$TYPE" = "vs" ]; then
        generator="Visual Studio ${VS_VER_GEN}"
        cmake -S . -B "$build_dir" \
            -G "$generator" \
            -A "${PLATFORM}" \
            -DPROJECT_ARCH="$project_arch" \
            -DUSE_SANDBOX=OFF \
            -DCEF_RUNTIME_LIBRARY_FLAG=/MD \
            -DCMAKE_BUILD_TYPE=Release \
            ${CMAKE_WIN_SDK}
        cmake --build "$build_dir" --config Release --target libcef_dll_wrapper -j"${PARALLEL_MAKE}"
    else
        if command -v ninja >/dev/null 2>&1; then
            cmake -S . -B "$build_dir" -G Ninja \
                -DPROJECT_ARCH="$project_arch" \
                -DUSE_SANDBOX=OFF \
                -DCMAKE_BUILD_TYPE=Release
        else
            cmake -S . -B "$build_dir" -G "Unix Makefiles" \
                -DPROJECT_ARCH="$project_arch" \
                -DUSE_SANDBOX=OFF \
                -DCMAKE_BUILD_TYPE=Release
        fi
        cmake --build "$build_dir" --config Release --target libcef_dll_wrapper -j"${PARALLEL_MAKE}"
    fi
}

function _cef_find_wrapper() {
    local build_dir="$1"
    local candidate
    for candidate in \
        "$build_dir/libcef_dll_wrapper/Release/libcef_dll_wrapper.lib" \
        "$build_dir/Release/libcef_dll_wrapper.lib" \
        "$build_dir/libcef_dll_wrapper/libcef_dll_wrapper.lib" \
        "$build_dir/libcef_dll_wrapper/libcef_dll_wrapper.a" \
        "$build_dir/libcef_dll_wrapper.a"
    do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    echoError "libcef_dll_wrapper was not built in $build_dir"
    return 1
}

function _cef_is_sample() {
    case "$1" in
        cefclient | cefsimple | ceftests | cefsimple_capi) return 0 ;;
        cefclient.* | cefsimple.* | ceftests.* | cefsimple_capi.*) return 0 ;;
        *) return 1 ;;
    esac
}

function _cef_copy_runtime() {
    local dest="$1"
    local item name
    mkdir -p "$dest"
    if [ -d "Release/Chromium Embedded Framework.framework" ]; then
        rm -rf "$dest/Chromium Embedded Framework.framework"
        cp -R "Release/Chromium Embedded Framework.framework" "$dest/"
        return 0
    fi
    if [ -d Release ]; then
        for item in Release/*; do
            [ -e "$item" ] || continue
            name="$(basename "$item")"
            if _cef_is_sample "$name"; then
                continue
            fi
            cp -R "$item" "$dest/"
        done
    fi
    if [ -d Resources ]; then
        cp -R Resources/. "$dest/"
    fi
}

function copy() {
    local dest="$1"
    local build_dir platform wrapper libdir
    build_dir="$(_cef_build_dir)"
    platform="$(_cef_platform)" || return 1
    wrapper="$(_cef_find_wrapper "$build_dir")" || return 1
    . "$SECURE_SCRIPT"

    mkdir -p "$dest/include"
    cp -R include/. "$dest/include/"
    if [ -d cmake ]; then
        mkdir -p "$dest/cmake"
        cp -R cmake/. "$dest/cmake/"
    fi

    libdir="$dest/lib/$TYPE/${PLATFORM:-$ARCH}"
    mkdir -p "$libdir"
    cp -v "$wrapper" "$libdir/"
    if [ "$TYPE" = "vs" ]; then
        secure "$libdir/libcef_dll_wrapper.lib" "cef.pkl" "$VER" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        if [ -f Release/libcef.lib ]; then
            cp -v Release/libcef.lib "$libdir/"
        fi
    else
        secure "$libdir/libcef_dll_wrapper.a" "cef.pkl" "$VER" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    _cef_copy_runtime "$libdir/runtime"

    mkdir -p "$dest/license"
    for notice in LICENSE.txt README.txt AUTHORS.txt; do
        if [ -f "$notice" ]; then
            cp -v "$notice" "$dest/license/"
        fi
    done
}

function clean() {
    local build_dir
    build_dir="$(_cef_build_dir)"
    if [ -d "$build_dir" ]; then
        rm -rf "$build_dir"
    fi
}
