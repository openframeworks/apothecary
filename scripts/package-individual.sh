#!/usr/bin/env bash
# set -e
# set -x

ROOT=$(
    cd $(dirname "$0")
    pwd -P
)/..
LOCAL_ROOT=$ROOT
APOTHECARY_PATH=$ROOT/apothecary

if [ -z "${NO_FORCE+x}" ]; then
    export FORCE="-f"
else
    export FORCE=""
fi
if [ -z "$1" ]; then
    TARGET=${TARGET:-$1}
else
    TARGET=$1
fi
if [ -z "$2" ]; then
    echo " Bundle: $2"
else
    BUNDLE=$2
fi
ARCH=${ARCH:-64}
if [ -z "${OUTPUT_FOLDER+x}" ]; then
    export OUTPUT_FOLDER="$ROOT/out"
fi
if [[ "$TARGET" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    export OUTPUT_FOLDER="$ROOT/xout"
fi
if [[ "$TARGET" =~ ^(macos)$ ]]; then
    export OUTPUT_FOLDER="$ROOT/xout_${BUNDLE}"
fi
if [ -z $TARGET ]; then
    echo "Environment variable TARGET not defined. Should be target os"
    exit 0
fi

source $LOCAL_ROOT/scripts/calculate_formulas.sh
if [ -z "$FORMULAS" ]; then
    echo "No formulas to build"
    exit 0
fi

CUR_BRANCH="master"
EXIT_BEFORE=0

if [ -n "${ALWAYS_BUILD+x}" ]; then
    echo "ALWAYS_BUILD is set - proceeding with build regardless of branch/tag"
    CUR_BRANCH="latest"
    RELEASE="latest"
else
    if [[ ("${GITHUB_REF##*/}" == "master" || "${GITHUB_REF##*/}" == "bleeding" || "${GITHUB_REF##*/}" == "latest") && -z "${GITHUB_HEAD_REF}" ]] ||
        [[ "${GITHUB_REF}" == refs/tags/* ]]; then

        # Check if we are on a tag
        if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
            echo "On a tag - proceeding with tag-specific build steps"
            RELEASE="${GITHUB_REF##*/}" # Use tag name as the release
            CUR_BRANCH="$RELEASE"
        else
            echo "On Master, Bleeding, or Latest branch - proceeding with branch-specific build steps"
            CUR_BRANCH="latest"
            RELEASE="latest"
        fi
    else
        echo "This is a PR or not on master/bleeding branch; exiting build before compressing."
        EXIT_BEFORE=1
    fi
fi

cd $OUTPUT_FOLDER

echo "Compressing individual libraries from [$OUTPUT_FOLDER]..."

for LIB in $FORMULAS; do
    if [ -d "$LIB" ]; then
        if [[ "$TARGET" == "msys2" || "$TARGET" == "vs" ]]; then
            # ZIP format for Windows (msys2 / vs)
            TARBALL="oF_${LIB}_${TARGET}_${ARCH}.zip"
            echo "Packaging $LIB -> $TARBALL"
            if [[ "$TARGET" == "msys2" ]]; then
                "C:\Program Files\7-Zip\7z.exe" a "$TARBALL" "$LIB"
            else
                "C:\Program Files\7-Zip\7z.exe" a "$TARBALL" "$LIB"
            fi
        else
            # TAR format for Linux/macOS/Emscripten
            TARBALL="oF_${LIB}_${TARGET}_${ARCH}.tar.bz2"
            echo "Packaging $LIB -> $TARBALL"
            tar cjvf "$TARBALL" "$LIB"
        fi

        if [ $? -eq 0 ]; then
            echo "Successfully created package: $TARBALL"
        else
            echo "Error: Failed to package $LIB"
        fi
    else
        echo "Warning: Skipping $LIB as it does not exist in $OUTPUT_FOLDER"
    fi
done

echo "All libraries have been packaged."
echo "Listing all created packages:"
find . -type f -name "*.tar.bz2"

cd ../
