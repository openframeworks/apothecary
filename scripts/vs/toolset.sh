#!/usr/bin/env bash
# Sourced by Apothecary. Keep the generator host separate from its compiler.
apothecary_vs_tools_version() {
    local root="$1" candidate selected="" prefix="${VS_TOOLS_VERSION:-}"
    for candidate in "$root"/*; do
        [ -d "$candidate" ] || continue
        candidate=${candidate##*/}
        case "$candidate" in
            "$prefix"|"$prefix".*) selected=$candidate ;;
        esac
    done
    if [ -z "$selected" ]; then
        echo "Requested MSVC tools $prefix are not installed in $root" >&2
        return 1
    fi
    printf '%s\n' "$selected"
}

apothecary_vs_configure_toolset() {
    [ -n "${VS_TOOLSET:-}" ] || return 0
    case "$VS_TOOLSET" in
        v142)
            # Recipes use VC_VERSION in output names; VS_VER describes the host.
            export VC_VERSION=142
            [ "${VS_COMPILER:-MSVC}" = MSVC ] || return 1
            case "${ARCH:-}" in
                32|64) ;;
                *) echo 'v142 currently supports Apothecary x86/x64 builds only' >&2; return 1 ;;
            esac
            export VS_TOOLS_VERSION="${VS_TOOLS_VERSION:-14.29}"
            case "$VS_TOOLS_VERSION" in
                14.29|14.29.*) ;;
                *) echo 'v142 requires MSVC 14.29 tools' >&2; return 1 ;;
            esac
            ;;
        *) echo "Unsupported explicit VS_TOOLSET: $VS_TOOLSET" >&2; return 1 ;;
    esac
    export VS_VER_DIR
    VS_VER_DIR=$(apothecary_vs_tools_version "$VS_BASE_PATH/VC/Tools/MSVC") || return 1
    export VS_BIN_PATH="$VS_BASE_PATH/VC/Tools/MSVC/$VS_VER_DIR/bin/$VS_HOSTPLATFORM/$BUILD_PLATFORM"
    [ -d "$VS_BIN_PATH" ] || { echo "Missing compiler directory: $VS_BIN_PATH" >&2; return 1; }
    export PATH="$VS_BIN_PATH:$PATH"
    export CC=cl CXX=cl
    export CMAKE_GENERATOR="Visual Studio ${VS_VER_GEN}"
    if [ -n "${VS_WINDOWS_SDK_VERSION:-}" ]; then
        if [[ ! $VS_WINDOWS_SDK_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo 'VS_WINDOWS_SDK_VERSION must be a literal four-part SDK version' >&2
            return 1
        fi
        export CMAKE_WIN_SDK="-DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=$VS_WINDOWS_SDK_VERSION -DCMAKE_SYSTEM_VERSION=$VS_WINDOWS_SDK_VERSION"
    fi
    case "$VS_HOSTPLATFORM" in
        Hostx64) export CMAKE_GENERATOR_TOOLSET="$VS_TOOLSET,version=$VS_VER_DIR,host=x64" ;;
        Hostx86) export CMAKE_GENERATOR_TOOLSET="$VS_TOOLSET,version=$VS_VER_DIR,host=x86" ;;
        *) echo "Unsupported v142 compiler host: $VS_HOSTPLATFORM" >&2; return 1 ;;
    esac
    export CMAKE_WIN_SDK="$CMAKE_WIN_SDK -T $CMAKE_GENERATOR_TOOLSET"
    # OF's VS2019 profile is C++17. Do not inherit C++23 or /std:c++latest
    # from the VS2022 generator host, including in the packaged Pkl metadata.
    export CPP_STANDARD=17
    unset CPP_STANDARD_MODE
    echo "MSVC toolset $VS_TOOLSET ($VS_VER_DIR), CMake C++ $CPP_STANDARD (${CPP_STANDARD_MODE:-standard})"
}
