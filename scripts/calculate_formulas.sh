#!/usr/bin/env bash
set -e
set -o pipefail

if [ -z "${1:-}" ]; then
    TARGET=${TARGET:-$1}
else
    TARGET=$1
fi

if [ "$TARGET" = "core" ] || [ "$TARGET" = "addons" ]; then
    if [ -n "${TYPE:-}" ]; then
        export TARGET="$TYPE"
    fi
fi

if [ -z "${TARGET:-}" ]; then
    if [ -n "${TYPE:-}" ]; then
        export TARGET="$TYPE"
    else
        echo "Environment variable TARGET not defined. Should be target os"
        exit 1
    fi
fi
echo "Target: $TARGET"
TBUNDLE=${BUNDLE:-0}
if [ -z "${2:-}" ]; then
    echo "BUNDLE:[$TBUNDLE]"
else
    TBUNDLE=$2
fi
FORMULAS=("${FORMULAS[@]:-}")
TARCH=${ARCH:-64}

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
    if [[ "$TARCH" =~ ^(64|arm64|x86_64)$ ]]; then
        FORMULAS+=(
           # "poco"
        )
    fi

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

    FORMULAS=()

    if [ "$TBUNDLE" == "1" ] || [ "$TBUNDLE" == "0" ]; then
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
    if [ "$TBUNDLE" == "2" ] || [ "$TBUNDLE" == "0" ]; then
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
    if [ "$TBUNDLE" == "3" ] || [ "$TBUNDLE" == "0" ]; then
        FORMULAS+=(
            "fmt"
            "openssl"
            "curl"
            "poco"
        )
    fi
elif [ "$TARGET" == "vs" ]; then
    FORMULAS=()
    if [ "$TBUNDLE" == "1" ] || [ "$TBUNDLE" == "0" ]; then
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
    if [ "$TBUNDLE" == "2" ] || [ "$TBUNDLE" == "0" ]; then
        FORMULAS+=(
            "fmt"
            "openssl"
            "curl"
            "poco"
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

echo "Potions to Brew - formulas: [${FORMULAS[@]}]"
if [ -z ${FORMULAS} ]; then
    echo "===No formulas to build, failing==="
    exit 1
fi

