#!/usr/bin/env bash
set -euo pipefail

OF_ROOT="${1:?usage: $0 OPENFRAMEWORKS_ROOT LIBRARY_REF PLATFORM}"
LIBRARY_REF="${2:?usage: $0 OPENFRAMEWORKS_ROOT LIBRARY_REF PLATFORM}"
PLATFORM="${3:?usage: $0 OPENFRAMEWORKS_ROOT LIBRARY_REF PLATFORM}"
REPOSITORY="${APOTHECARY_REPOSITORY:-openframeworks/apothecary}"
SNAPSHOT_MANIFEST="${4:-}"
if [[ -n "$SNAPSHOT_MANIFEST" ]]; then
    SCRIPT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    node "$SCRIPT_ROOT/install-nightly-candidate.cjs" "$SNAPSHOT_MANIFEST" "$OF_ROOT" "$PLATFORM"
    exit
fi

case "$PLATFORM" in
    linux) OF_PLATFORM="linux"; MODULAR_SUFFIX="linux_64_gcc14" ;;
    macos) OF_PLATFORM="osx"; MODULAR_SUFFIX="osx_64" ;;
    ios|tvos) OF_PLATFORM="macos"; MODULAR_SUFFIX="macos" ;;
    android) OF_PLATFORM="android"; MODULAR_SUFFIX="android_arm64" ;;
    emscripten) OF_PLATFORM="emscripten"; MODULAR_SUFFIX="emscripten_64" ;;
    windows) OF_PLATFORM="vs"; MODULAR_SUFFIX="vs_64" ;;
    *) echo "unsupported integration platform: $PLATFORM" >&2; exit 2 ;;
esac

install_modular() {
    command -v gh >/dev/null || { echo "gh is required for modular releases" >&2; return 1; }
    local download_dir="$OF_ROOT/libs/download/latest-modular"
    local asset archive name destination required_name found=0 installed=$'\n'
    local -a required=()
    mkdir -p "$download_dir"

    while IFS= read -r asset; do
        [[ -n "$asset" ]] || continue
        found=$((found + 1))
        archive="$download_dir/$asset"
        gh release download latest-modular -R "$REPOSITORY" -p "$asset" -D "$download_dir" --clobber

        case "$asset" in
            *.tar.bz2) tar -xjf "$archive" -C "$download_dir" ;;
            *.tar.gz) tar -xzf "$archive" -C "$download_dir" ;;
            *.zip) unzip -qo "$archive" -d "$download_dir" ;;
            *) echo "unsupported modular archive: $asset" >&2; return 1 ;;
        esac

        name="${asset#oF_}"
        name="${name%_${MODULAR_SUFFIX}.tar.bz2}"
        name="${name%_${MODULAR_SUFFIX}.tar.gz}"
        name="${name%_${MODULAR_SUFFIX}.zip}"
        installed+="${name}"$'\n'
        case "$name" in
            assimp) destination="$OF_ROOT/addons/ofxAssimpModelLoader/libs" ;;
            opencv|ippicv) destination="$OF_ROOT/addons/ofxOpenCv/libs" ;;
            libusb|libfreenect) destination="$OF_ROOT/addons/ofxKinect/libs" ;;
            libxml2|svgtiny) destination="$OF_ROOT/addons/ofxSvg/libs" ;;
            oscpack) destination="$OF_ROOT/addons/ofxOsc/libs" ;;
            *) destination="$OF_ROOT/libs" ;;
        esac
        mkdir -p "$destination"
        [[ -d "$download_dir/$name" ]] || {
            echo "modular archive $asset did not contain its expected $name directory" >&2
            return 1
        }
        rm -rf "$destination/$name"
        mv "$download_dir/$name" "$destination/$name"
    done < <(gh api "repos/$REPOSITORY/releases/tags/latest-modular" --jq \
        ".assets[].name | select(test(\"^oF_.+_${MODULAR_SUFFIX}\\\\.(tar\\\\.bz2|tar\\\\.gz|zip)$\"))")

    [[ "$found" -gt 0 ]] || {
        echo "latest-modular has no assets for $PLATFORM ($MODULAR_SUFFIX)" >&2
        return 1
    }

    case "$PLATFORM" in
        linux)
            required=(glm json utf8 brotli zlib libpng glew glfw freetype libxml2
                svgtiny tess2 kiss FreeImage fmt uriparser pixman)
            ;;
        macos|ios|tvos)
            required=(zlib utf8 libpng brotli pugixml freetype libxml2 svgtiny
                FreeImage assimp glew rtAudio tess2 uriparser cairo glm json glfw
                opencv portaudio libusb fmt openssl curl poco)
            ;;
        emscripten)
            required=(pixman brotli zlib assimp libpng FreeImage libxml2 freetype
                glew glfw glm json libusb kiss opencv openssl portaudio pugixml
                utf8 videoInput rtAudio tess2 uriparser curl svgtiny cairo fmt)
            ;;
        android)
            required=(metalangle glm json utf8 brotli zlib libxml2 svgtiny tess2
                kiss fmt libpng pugixml uriparser freetype FreeImage assimp opencv
                openssl curl)
            ;;
        windows)
            required=(fmt freetype glew glfw glm json openssl poco pugixml
                uriparser utf8 zlib)
            ;;
    esac
    local -a missing=()
    for required_name in "${required[@]}"; do
        [[ "$installed" == *$'\n'"$required_name"$'\n'* ]] || missing+=("$required_name")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        printf 'latest-modular is incomplete for %s; missing packages:' "$PLATFORM" >&2
        printf ' %s' "${missing[@]}" >&2
        printf '\n' >&2
        return 1
    fi
}

install_monolithic() {
    local tag
    case "$LIBRARY_REF" in
        bleeding|latest) tag="latest" ;;
        master) tag="nightly" ;;
        *) tag="$LIBRARY_REF" ;;
    esac
    local script="$OF_ROOT/scripts/$OF_PLATFORM/download_libs.sh"
    [[ -f "$script" ]] || { echo "openFrameworks downloader missing: $script" >&2; return 1; }
    bash "$script" -t "$tag"
}

if [[ "$LIBRARY_REF" == "latest-modular" ]]; then
    install_modular
else
    install_monolithic
fi

echo "Libraries ready: $LIBRARY_REF for $PLATFORM"
