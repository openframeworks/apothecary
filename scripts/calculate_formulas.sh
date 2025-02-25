#!/usr/bin/env bash
set -e
set -o pipefail

if [ -z "${TARGET:-}" ]; then
    if [ -n "${TYPE:-}" ]; then
        export TARGET="$TYPE"
    else
        echo "Environment variable TARGET not defined. Should be target os"
        exit 1
    fi
fi
FORMULAS=("${FORMULAS[@]:-}")
BUNDLE=${BUNDLE:-0}

FORMULAS=(
    # sub Dependencies at top
    "pixman"
    "brotli"
    "pkg-config"
    "zlib"
    "assimp"
    # "boost"
    "libpng"
    "FreeImage"
    "libxml2"
    "freetype"
    #"fmod"
    "glew"
    "glfw"
    "glm"
    "json"
    "libusb"
    "kiss"
    "opencv"
    "openssl"
    "portaudio"
    "pugixml"
    "utf8"
    "videoInput"
    "rtAudio"
    "tess2"
    "uriparser"
    "curl"
    # "poco"
    "svgtiny"
    "cairo"
    "fmt"
    "metalangle"
)

if [[ "$TARGET" =~ ^(linux)$ ]]; then
    FORMULAS=(
        "pkg-config"
        "glm"
        "json"
        "utf8"
        "brotli"
        "zlib"
        "libpng"
        "glew"
        "glfw"
        "freetype"
        "libxml2"
        "svgtiny"
        "tess2"
        "kiss"
        "FreeImage"
        "fmt"
        "uriparser"
    )
elif [[ "$TARGET" =~ ^(android)$ ]]; then
    FORMULAS=(
        "pkg-config"
        "glm"
        "json"
        "utf8"
        "brotli"
        "zlib"
        "libxml2"
        "svgtiny"
        "tess2"
        "kiss"
        "fmt"
        "pugixml"
        "uriparser"
        "freetype"
        "FreeImage"
        "assimp"
    )
elif [[ "$TARGET" =~ ^(osx|macos|ios|tvos|xros|catos|watchos)$ ]]; then
    if [ "$BUNDLE" == "1" ] || [ "$BUNDLE" == "0" ]; then
        FORMULAS=(
            "pixman"
            "pkg-config"
            "zlib"
            "utf8"
            "libpng"
            "brotli"
            "pugixml"
            "freetype"
            "libxml2"
            "svgtiny"
            "FreeImage"
            "assimp"
            "glew"
            "videoInput"
            "rtAudio"
            "tess2"
            "uriparser"
            "metalangle"
            "cairo"
        )
    fi
    if [ "$BUNDLE" == "2" ] || [ "$BUNDLE" == "0" ]; then
        if [[ "$TARGET" =~ ^(osx|macos)$ ]]; then
            FORMULAS+=(
                "glm"
                "json"
                "zlib"
                "glfw"
                "opencv"
                "portaudio"
                "libusb"
                # "fmod"
            )
        else
            FORMULAS+=(
                "glm"
                "json"
                "opencv"
            )
        fi
    fi
    if [ "$BUNDLE" == "3" ] || [ "$BUNDLE" == "0" ]; then
        FORMULAS+=(
            "fmt"
            "openssl"
            "curl"
            # "poco"
        )
    fi
elif [ "$TARGET" == "vs" ]; then
    if [ "$BUNDLE" == "1" ] || [ "$BUNDLE" == "0" ]; then
        FORMULAS=(
            # Dependencies for other formulas (cairo)
            "pixman"
            "pkg-config"
            "zlib"
            "libpng"
            "brotli"
            "freetype"
            "libxml2"
            "svgtiny"
            "assimp"
            "FreeImage"
            "glew"
            "glfw"
            "glm"
            "json"
            "libusb"
            "kiss"
            "portaudio"
            "pugixml"
            "utf8"
            "videoInput"
            "rtAudio"
            "tess2"
            "uriparser"
            "opencv"
            "cairo"
        )
    fi
    if [ "$BUNDLE" == "2" ] || [ "$BUNDLE" == "0" ]; then
        FORMULAS+=(
            "fmt"
            "openssl"
            "curl"
            # "poco"
        )
    fi
fi

array_contains() {
    local array="$1[@]"
    local seeking=$2
    local in=0
    for element in "${!array}"; do
        if [[ $element == $seeking ]]; then
            in=1
            break
        fi
    done
    return $in
}

echo "Potions to Brew with formulas: [${FORMULAS[@]}]"
if [ -z ${FORMULAS} ]; then
    echo "===No formulas to build, failing==="
    exit 1
fi

