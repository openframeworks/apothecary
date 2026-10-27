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
    case "$VS_HOSTPLATFORM" in
        Hostx64) export CMAKE_GENERATOR_TOOLSET="$VS_TOOLSET,version=$VS_VER_DIR,host=x64" ;;
        Hostx86) export CMAKE_GENERATOR_TOOLSET="$VS_TOOLSET,version=$VS_VER_DIR,host=x86" ;;
        *) echo "Unsupported v142 compiler host: $VS_HOSTPLATFORM" >&2; return 1 ;;
    esac
    export CMAKE_WIN_SDK="$CMAKE_WIN_SDK -T $CMAKE_GENERATOR_TOOLSET"
    if [ "${CPP_STANDARD:-}" = max ]; then
        # CMake maps CXX_STANDARD=23 to /std:c++latest on MSVC 19.29.
        # This does not mean the VS2019 compiler implements all of C++23.
        export CPP_STANDARD=23
        export CPP_STANDARD_MODE=latest
    elif [ "${CPP_STANDARD:-}" != 23 ]; then
        unset CPP_STANDARD_MODE
    fi
    echo "MSVC toolset $VS_TOOLSET ($VS_VER_DIR), CMake C++ $CPP_STANDARD (${CPP_STANDARD_MODE:-standard})"
}
