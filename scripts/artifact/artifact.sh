#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

ROOT=$(
    cd $(dirname "$0")
    pwd -P
)/../../
LOCAL_ROOT=$ROOT
APOTHECARY_PATH=$ROOT/apothecary
if [ -z "${OUTPUT_FOLDER+x}" ]; then
    export OUTPUT_FOLDER="$ROOT/out"
fi

echo "ROOT: $ROOT"
echo "APOTHECARY_PATH: $APOTHECARY_PATH"
echo "OUTPUT_FOLDER: $OUTPUT_FOLDER"

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
    export OUTPUT_FOLDER="$ROOT/out"
fi
if [ -z $TARGET ]; then
    echo "Environment variable TARGET not defined. Should be target os"
    exit 0
fi

CUR_BRANCH="master"
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
        # Exit early if this is a PR or a branch we don't want to build
        exit 0
    fi
fi

echo "Compressing libraries from $OUTPUT_FOLDER"
cd $OUTPUT_FOLDER
LIBS=$(ls $OUTPUT_FOLDER)
LIBS=$(echo "$LIBS" | tr '\n' ' ')

if [ -z "${RELEASE+x}" ]; then
    if [ "$GITHUB_ACTIONS" = true ]; then
        CUR_BRANCH="${GITHUB_REF##*/}"
    elif [ "$TRAVIS" = true ]; then
        CUR_BRANCH="$TRAVIS_BRANCH"
    fi
else
    CUR_BRANCH="$RELEASE"
fi


TARBALL=openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2
if [ "$TARGET" == "linux" ]; then
    if [ -n "$GCC" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}_${GCC}.tar.bz2"
    else
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2"
    fi
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    echo "cd ${OUTPUT_FOLDER}; tar cjf $TARBALL $LIBS"
    tar -cjvf $TARBALL $LIBS
    if [ $? -eq 0 ]; then
        echo "Successfully created tarball: $TARBALL"
    else
        echo "Error: Failed to create tarball."
        exit 1
    fi
elif [ "$TARGET" == "msys2" ]; then
    if [ -n "$MSYSTEM" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${MSYSTEM}.zip"
    else
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}.zip"
    fi
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    "C:\Program Files\7-Zip\7z.exe" a $TARBALL $LIBS
    echo "C:\Program Files\7-Zip\7z.exe a $TARBALL $LIBS"
elif [ "$TARGET" == "vs" ]; then
    if [ ! -z "${VS_VER+x}" ]; then
        if [ "${VS_VER}" == "16" ]; then
            echo "VS2019 Version"
            TARGET="${TARGET}_2019"
        fi
    fi
    if [ -n "$BUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}_${BUNDLE}.zip"
    else
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.zip"
    fi
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    "C:\Program Files\7-Zip\7z.exe" a $TARBALL $LIBS
    echo "C:\Program Files\7-Zip\7z.exe a $TARBALL $LIBS"
elif [ "$TARGET" == "emscripten" ]; then
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
    TARBALL=openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    sudo tar cjvf $TARBALL $LIBS
elif [ "$TARGET" == "android" ]; then
    TARBALL=openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2
    echo "TARBALL: [$TARBALL]"
    echo "tar cjf $TARBALL $LIBS"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    tar cjvf $TARBALL $LIBS
elif [ "$TARGET" == "macos" ]; then
    if [ -n "$BUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${BUNDLE}.tar.bz2"
    else
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}.tar.bz2"
    fi
    echo "TARBALL: [$TARBALL]"
    echo "tar cjf $TARBALL $LIBS"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    tar cjvf $TARBALL $LIBS
elif [[ "$TARGET" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    if [ -n "$BUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${BUNDLE}.tar.bz2"
    else
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}.tar.bz2"
    fi
    echo "TARBALL: [$TARBALL]"
    echo "tar cjf ${TARBALL} ${LIBS}"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    tar cjvf "${TARBALL}" ${LIBS}
else
    echo "tar cjf $TARBALL $LIBS"
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    tar cjvf $TARBALL $LIBS
fi

echo "Artefact Package libs to upload $TARBALL"
echo "done "

pwd
find ./ -type f \( -name "*.zip" -o -name "*.tar.bz2" \) -exec echo {} \;
cd ../
