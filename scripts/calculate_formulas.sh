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
    "nghttp2"
    "nghttp3"
    "ngtcp2"
    "libssh2"
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
        # dawn: not in core until Linux CI is GCC 11+ (atomic::wait / bit_cast)
        # TYPE=linux ./apo update dawn
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
        "libpng"
        "pugixml"
        "uriparser"
        "freetype"
        "FreeImage"
        "assimp"
        "opencv"
        "openssl"
        "nghttp2"
        "nghttp3"
        "ngtcp2"
        "libssh2"
        "curl"
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
            "cairo"
        )
        # metalangle: MGLKit (osx/ios/tvos). google/angle GN is opt-in until gn gen is green.
        if [[ "$TARGET" =~ ^(osx|macos|ios|tvos)$ ]]; then
            FORMULAS+=("metalangle")
        fi
        # TYPE=osx|ios|tvos|catos|xros ./apo update angle
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
            "nghttp2"
            "nghttp3"
            "ngtcp2"
            "libssh2"
            "curl"
        )
        # Poco is built separately for iOS and published only as a modular
        # release asset, not as part of the monolithic iOS bundle.
        if [ "$TARGET" != "ios" ]; then
            FORMULAS+=("poco")
        fi
        # Dawn is Metal on Apple; watchOS SDK has no Metal.framework.
        if [ "$TARGET" != "watchos" ]; then
            FORMULAS+=("dawn")
        fi
    fi
elif [[ "$TARGET" =~ ^(vs|msys2)$ ]]; then
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
            "nghttp2"
            "nghttp3"
            "ngtcp2"
            "libssh2"
            "curl"
            "poco"
            "dawn"
            # angle / glon12: not in core — GN/gclient and Mesa meson are opt-in
            # TYPE=vs ./apo update angle
            # TYPE=vs ./apo update glon12
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

if [ -n "${FORMULAS_OVERRIDE:-}" ]; then
    # shellcheck disable=SC2206
    FORMULAS=(${FORMULAS_OVERRIDE})
    echo "FORMULAS_OVERRIDE: [${FORMULAS[*]}]"
fi

# Built for curl and merged into libcurl. Keep in FORMULAS for brew order
# and pickles. Do not xcframework or put in the published tarball.
FORMULAS_INTERNAL=("nghttp2" "nghttp3" "ngtcp2" "libssh2")

formula_is_internal() {
    local name="$1"
    local f
    for f in "${FORMULAS_INTERNAL[@]}"; do
        if [ "$f" = "$name" ]; then
            return 0
        fi
    done
    return 1
}

echo "Potions to Brew - formulas: [${FORMULAS[@]}]"
if [ -z ${FORMULAS} ]; then
    echo "===No formulas to build, failing==="
    exit 1
fi
