#!/usr/bin/env bash
# Relocate CMake + pkg-config files that cmake --install emits with absolute
# build-tree paths, and generate missing ones from the apothecary .pkl sidecar.
#
# Layout (issue #405):
#   $DEST/lib/$TYPE/$PLATFORM/*.pc              next to the .a / .lib (like pkl)
#   $DEST/lib/$TYPE/$PLATFORM/pkgconfig/*.pc    also kept if cmake installed here
#   $DEST/lib/$TYPE/$PLATFORM/cmake/*.cmake     versioned cmake configs
#
# Usage:
#   export_config.sh <DEST> [PLATFORM] [ARCH]
# Sourced from copyFormula; also runnable after a full out/ tree.

set -euo pipefail

apo_pc_relocate() {
    local pkg_file="$1"
    [ -f "$pkg_file" ] || return 0
    # pc next to lib/$TYPE/$PLATFORM/*.a  →  prefix is ../../..
    # pc in  lib/$TYPE/$PLATFORM/pkgconfig →  prefix is ../../../..
    local prefix_rel="\${pcfiledir}/../../.."
    local libdir_rel="\${pcfiledir}"
    case "$pkg_file" in
        */pkgconfig/*.pc)
            prefix_rel="\${pcfiledir}/../../../.."
            libdir_rel="\${pcfiledir}/.."
            ;;
    esac

    local inc_suffix="/include"
    local old_inc
    old_inc=$(grep -E '^includedir=' "$pkg_file" | head -1 | cut -d= -f2- || true)
    if [[ "$old_inc" == *"/include/"* ]]; then
        inc_suffix="/include/${old_inc##*/include/}"
    fi

    local tmp="${pkg_file}.apo.tmp"
    grep -v -E '^(prefix|exec_prefix|libdir|includedir)=' "$pkg_file" >"$tmp" || true
    {
        echo "prefix=${prefix_rel}"
        echo "exec_prefix=\${prefix}"
        echo "libdir=${libdir_rel}"
        echo "includedir=\${prefix}${inc_suffix}"
        cat "$tmp"
    } >"${pkg_file}.new"
    mv -f "${pkg_file}.new" "$pkg_file"
    rm -f "$tmp"
}

apo_cmake_relocate() {
    local cmake_file="$1"
    local dest_root="$2"
    [ -f "$cmake_file" ] || return 0
    # Replace the formula dest and common cmake install prefixes with a
    # relocatable prefix computed from CMAKE_CURRENT_LIST_DIR.
    local dest_abs=""
    if [ -n "$dest_root" ]; then
        dest_abs=$(cd "$dest_root" 2>/dev/null && pwd -P || echo "$dest_root")
    fi
    # cmake/ subdir is four levels below formula root; next-to-lib is three.
    local list_rel="\${CMAKE_CURRENT_LIST_DIR}/../../.."
    case "$cmake_file" in
        */cmake/*.cmake) list_rel="\${CMAKE_CURRENT_LIST_DIR}/../../../.." ;;
    esac
    local tmp="${cmake_file}.apo.tmp"
    cp "$cmake_file" "$tmp"
    if [ -n "$dest_abs" ]; then
        # Escape for sed
        local esc
        esc=$(printf '%s' "$dest_abs" | sed 's/[][\\.*^$]/\\&/g')
        sed -i.bak "s|${esc}|${list_rel}|g" "$tmp" || true
        rm -f "${tmp}.bak"
    fi
    # Common cmake --install prefix used by formulas (Release/)
    sed -i.bak -E 's|/[^ ]+/Release|'"${list_rel}"'|g' "$tmp" 2>/dev/null || true
    rm -f "${tmp}.bak"
    mv -f "$tmp" "$cmake_file"
}

apo_write_pc() {
    local pc_file="$1"
    local libname="$2"
    local version="$3"
    local libs="$4"
    local requires="$5"
    local cflags="$6"
    mkdir -p "$(dirname "$pc_file")"
    cat >"$pc_file" <<EOF
prefix=\${pcfiledir}/../../..
exec_prefix=\${prefix}
libdir=\${pcfiledir}
includedir=\${prefix}/include

Name: ${libname}
Description: ${libname} (apothecary)
Version: ${version}
Requires: ${requires}
Libs: ${libs}
Cflags: -I\${includedir} ${cflags}
EOF
}

apo_write_cmake_config() {
    local cmake_file="$1"
    local libname="$2"
    local version="$3"
    local binary="$4"
    local libname_upper
    libname_upper=$(printf '%s' "$libname" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_')
    mkdir -p "$(dirname "$cmake_file")"
    cat >"$cmake_file" <<EOF
# ${libname}Config.cmake — relocatable apothecary install (issue #405)
# Version: ${version}

get_filename_component(${libname_upper}_LIBDIR "\${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
get_filename_component(${libname_upper}_PREFIX "\${CMAKE_CURRENT_LIST_DIR}/../../../.." ABSOLUTE)
set(${libname_upper}_INCLUDE_DIR "\${${libname_upper}_PREFIX}/include")

find_library(${libname_upper}_LIBRARY
    NAMES ${libname} ${binary%.a} ${binary%.lib}
    PATHS "\${${libname_upper}_LIBDIR}"
    NO_DEFAULT_PATH
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(${libname}
    REQUIRED_VARS ${libname_upper}_LIBRARY ${libname_upper}_INCLUDE_DIR
    VERSION_VAR ${libname_upper}_VERSION
)

set(${libname_upper}_VERSION "${version}")
if(${libname}_FOUND)
    set(${libname_upper}_INCLUDE_DIRS "\${${libname_upper}_INCLUDE_DIR}")
    set(${libname_upper}_LIBRARIES "\${${libname_upper}_LIBRARY}")
    if(NOT TARGET apothecary::${libname})
        add_library(apothecary::${libname} STATIC IMPORTED)
        set_target_properties(apothecary::${libname} PROPERTIES
            IMPORTED_LOCATION "\${${libname_upper}_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "\${${libname_upper}_INCLUDE_DIR}"
        )
    endif()
endif()
mark_as_advanced(${libname_upper}_INCLUDE_DIR ${libname_upper}_LIBRARY)
EOF
}

apo_extract_pkl() {
    local pkl_file="$1"
    local key="$2"
    awk -F' *= *' -v key="$key" '$1 == key {gsub(/"/, "", $2); print $2}' "$pkl_file" | tr -d '\n'
}

apo_harvest_from_build() {
    local dest="$1"
    local libdir="$2"
    local name
    name=$(basename "$dest")
    local build_root="${BUILD_DIR:-}"
    [ -n "$build_root" ] && [ -d "$build_root/$name" ] || return 0
    mkdir -p "$libdir/pkgconfig" "$libdir/cmake"
    local src
    set +o pipefail
    while IFS= read -r src; do
        [ -f "$src" ] || continue
        cp -f "$src" "$libdir/pkgconfig/$(basename "$src")"
    done < <(find "$build_root/$name" \( -path '*/Release/lib/pkgconfig/*.pc' -o -path '*/Release/share/pkgconfig/*.pc' -o -path '*/lib/pkgconfig/*.pc' \) -type f 2>/dev/null | head -40)
    while IFS= read -r src; do
        [ -f "$src" ] || continue
        cp -f "$src" "$libdir/cmake/$(basename "$src")"
    done < <(find "$build_root/$name" \( -path '*/Release/lib/cmake/*/*.cmake' -o -path '*/lib/cmake/*/*.cmake' \) -type f 2>/dev/null | head -80)
    set -o pipefail
}

apo_install_formula_configs() {
    local dest="$1"
    local platform="${2:-${PLATFORM:-${ARCH:-}}}"
    local arch="${3:-${ARCH:-}}"
    [ -d "$dest" ] || return 0

    local type="${TYPE:-}"
    local libdir=""
    if [ -n "$type" ] && [ -n "$platform" ] && [ -d "$dest/lib/$type/$platform" ]; then
        libdir="$dest/lib/$type/$platform"
    elif [ -n "$type" ] && [ -n "$arch" ] && [ -d "$dest/lib/$type/$arch" ]; then
        libdir="$dest/lib/$type/$arch"
    else
        libdir=$(find "$dest/lib" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | head -1 || true)
    fi
    [ -n "$libdir" ] && [ -d "$libdir" ] || return 0

    echo "install cmake/pkgconfig for $(basename "$dest") → $libdir"

    apo_harvest_from_build "$dest" "$libdir"

    local f
    for f in "$libdir"/*.pc "$libdir"/pkgconfig/*.pc; do
        [ -f "$f" ] || continue
        apo_pc_relocate "$f"
    done
    mkdir -p "$libdir/cmake"
    for f in "$libdir"/*.cmake "$libdir"/cmake/*.cmake; do
        [ -f "$f" ] || continue
        apo_cmake_relocate "$f" "$dest"
    done

    local pkl
    for pkl in "$libdir"/*.pkl; do
        [ -f "$pkl" ] || continue
        local libname version binary deps defines
        libname=$(apo_extract_pkl "$pkl" "name")
        version=$(apo_extract_pkl "$pkl" "version")
        binary=$(apo_extract_pkl "$pkl" "binary")
        deps=$(apo_extract_pkl "$pkl" "dependencies")
        defines=$(apo_extract_pkl "$pkl" "defines")
        libname="${libname:-$(basename "$pkl" .pkl)}"
        version="${version:-0}"
        binary="${binary:-lib${libname}.a}"
        deps="${deps:-}"
        defines=$(printf '%s' "${defines:-}" | tr '\n' ' ' | sed 's/-DCMAKE_[^ ]*//g' | tr -s ' ')

        local pc="$libdir/${libname}.pc"
        if [ ! -f "$pc" ] && [ ! -f "$libdir/pkgconfig/${libname}.pc" ]; then
            local linkname="${libname}"
            linkname="${linkname%.pkl}"
            apo_write_pc "$pc" "$libname" "$version" "-L\${libdir} -l${linkname}" "$deps" "$defines"
        fi
        local cmake_cfg="$libdir/cmake/${libname}Config.cmake"
        if [ ! -f "$cmake_cfg" ]; then
            apo_write_cmake_config "$cmake_cfg" "$libname" "$version" "$binary"
        fi
    done
}

# Executed as a script (not sourced).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ "${1:-}" = "--all" ]; then
        root="${2:-${OUTPUT_FOLDER:-}}"
        if [ -z "$root" ]; then
            echo "Usage: $0 --all <out-dir>" >&2
            exit 1
        fi
        for dest in "$root"/*/; do
            [ -d "$dest" ] || continue
            apo_install_formula_configs "${dest%/}"
        done
        exit 0
    fi
    if [ "$#" -lt 1 ]; then
        echo "Usage: $0 <DEST> [PLATFORM] [ARCH]" >&2
        echo "       $0 --all <out-dir>" >&2
        exit 1
    fi
    apo_install_formula_configs "$1" "${2:-}" "${3:-}"
fi
