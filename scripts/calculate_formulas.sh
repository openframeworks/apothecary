#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

FORMULAS=(
    # Dependencies for other formulas (cairo)
    "pixman"
    "pkg-config"
    "zlib"

    # All formulas
    "assimp"
    "boost"
    "FreeImage"
    "libpng"
    "libxml2"
    "freetype"
    "fmod"
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

    # Formulas with depenencies in the end
    "curl"
    "poco"
    "svgtiny"
    "uri"
    "cairo"
)

# Seperate in bundles on osx
if [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ] || [ "$TARGET" == "osx" ] || [ "$TARGET" == "vs" ]; then
    if [ "$BUNDLE" == "1" ]; then
        FORMULAS=(
            # Dependencies for other formulas (cairo)
            "pixman"
            "pkg-config"
            "zlib"
            "libpng"
            "freetype"

            # All formulas
            "boost"
            "FreeImage"
            "fmod"
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

            # # Formulas with depenencies in the end
            "cairo"
            "uri"
        )
    elif [ "$BUNDLE" == "2" ]; then
        if [ "$TARGET" == "tvos" ]; then
            FORMULAS=(
                "openssl"
                "curl"
            )
        else
            FORMULAS=(
                "openssl"
                "curl"
                "poco"
            )
        fi
    elif [ "$BUNDLE" == "3" ]; then
        FORMULAS=(
            "libxml2"
            "svgtiny"
            "assimp"
        )
    elif [ "$BUNDLE" == "4" ]; then
        FORMULAS=(
            "opencv"
        )
    fi
fi



array_contains () {
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

# If commit contains [build_only:formula1 formula2] only those formulas will be built
# this will only work on a pull request, not when commiting to master
if [[ ! -z "${APPVEYOR+x}" && "${APPVEYOR_REPO_NAME}" != "openframeworks/apothecary" ]]; then
    echo ${APPVEYOR_REPO_NAME}
fi
if [[ ! -z "${TRAVIS_BRANCH+x}" && "$TRAVIS_BRANCH" != "master" && "$TRAVIS_PULL_REQUEST" != "false" ]] || [[ ! -z "${APPVEYOR+x}" && "${APPVEYOR_REPO_NAME}" != "openframeworks/apothecary" ]]; then
    echo "DETECTED PULL REQUEST OR NOT MASTER BRANCH, CHECKING FILTERS"
    COMMIT_MESSAGE="$(git log  --no-decorate -n1 --no-merges)"
    echo "COMMIT_MESSAGE $COMMIT_MESSAGE"
    FORMULAS_FROM_COMMIT=($(echo $COMMIT_MESSAGE | sed -n "s/.*\[build_only:\([^]]*\)\]/\1/p" | sed "s/\[.*\]//g"))
    PLATFORMS_FROM_COMMIT=($(echo $COMMIT_MESSAGE | sed -n "s/.*\[platforms_only:\([^]]*\)\]/\1/p" | sed "s/\[.*\]//g"))
fi

echo "FORMULAS_FROM_COMMIT: $FORMULAS_FROM_COMMIT"
if [ ! -z "$FORMULAS_FROM_COMMIT" ]; then
    FILTERED_FORMULAS=()
    for formula in $FORMULAS_FROM_COMMIT; do
        if [[ " ${FORMULAS[*]} " == *" $formula "* ]]; then
            FILTERED_FORMULAS+=($formula)
        fi
        # array_contains $FORMULAS $formula && FILTERED_FORMULAS+=($formula)
    done
    echo "FILTERED_FORMULAS: $FILTERED_FORMULAS"
    FORMULAS=(${FILTERED_FORMULAS})
fi

echo "FORMULAS: ${FORMULAS[@]}"

if [ -z ${FORMULAS} ]; then
    echo "No formulas to build, failing"
    exit 1
fi

echo "PLATFORMS_FROM_COMMIT: $PLATFORMS_FROM_COMMIT"
if [ ! -z "$PLATFORMS_FROM_COMMIT" ]; then
    if [[ " ${PLATFORMS_FROM_COMMIT[*]} " == *" $TARGET "* ]]; then
        echo "Platform $TARGET allowed in commit message"
        exit 0
    else
        echo "Platform $TARGET NOT allowed in commit message"
        exit 1
    fi
fi

