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
PBUNDLE=${BUNDLE:-0}
if [ -z "$2" ]; then
    echo "packge BUNDLE:[$PBUNDLE]"
else
    PBUNDLE=$2
fi
ARCH=${ARCH:-64}
if [ -z "${OUTPUT_FOLDER+x}" ]; then
    export OUTPUT_FOLDER="$ROOT/out"
fi
if [[ "$TARGET" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    export OUTPUT_FOLDER="$ROOT/xout"
fi
if [[ "$TARGET" =~ ^(macos)$ ]]; then
    export OUTPUT_FOLDER="$ROOT/xout_${PBUNDLE}"
fi
if [ -z $TARGET ]; then
    echo "Environment variable TARGET not defined. Should be target os"
    exit 0
fi

source $LOCAL_ROOT/scripts/calculate_formulas.sh $TARGET $PBUNDLE
if [ -z "$FORMULAS" ]; then
    echo "No formulas to build"
    exit 0
fi


CUR_BRANCH="master"
EXIT_BEFORE=0

if [ -n "${RELEASE:-}" ]; then
    echo "Explicit release identity '$RELEASE' - proceeding with packaging"
    CUR_BRANCH="$RELEASE"
elif [ -n "${ALWAYS_BUILD+x}" ]; then
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
        EXIT_BEFORE=1
    fi
fi


LIBS=$(ls $OUTPUT_FOLDER)
LIBS=$(echo "$LIBS" | tr '\n' ' ')
LIBS=""
for LIB in "${FORMULAS[@]}"; do
    LIB=$(echo "$LIB" | tr -d '[:space:]')  # Remove all whitespace
    if formula_is_modular_only "$LIB"; then
        echo "Skipping modular-only formula '$LIB' from the core archive"
        continue
    fi
    if formula_is_internal "$LIB"; then
        echo "Skipping internal formula '$LIB' (merged into curl)"
        continue
    fi
    if [ -d "$OUTPUT_FOLDER/$LIB" ] || [ -f "$OUTPUT_FOLDER/$LIB" ]; then
        LIBS="$LIBS $LIB"
    else
        echo "Warning: Formula '$LIB' not found in $OUTPUT_FOLDER"
    fi
done
LIBS=$(echo "$LIBS" | xargs)
LIBS=$(echo "$LIBS" | tr '\n' ' ')
cd $OUTPUT_FOLDER

if [ -z "${RELEASE+x}" ]; then
    if [ "${GITHUB_ACTIONS:-0}" = true ]; then
        CUR_BRANCH="${GITHUB_REF##*/}"
    elif [ "$TRAVIS" = true ]; then
        CUR_BRANCH="$TRAVIS_BRANCH"
    fi
else
    CUR_BRANCH="$RELEASE"
fi
GCC=${GCC:-}
if [ -z "$LIBS" ]; then
    echo "Error: LIBS is empty. Nothing to package."
    exit 1
fi
echo "Compressing Libraries : [$LIBS] ... to "
echo "   from [$OUTPUT_FOLDER]"

echo "Release: [$RELEASE]"
echo "TARGET: [$TARGET]"
echo "Current Branch: [$CUR_BRANCH]"
echo "Current ARCH: [$ARCH]"
echo "Current PBUNDLE: [$PBUNDLE]"

TARBALL=openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2
if [ "$TARGET" == "linux" ]; then
    # shellcheck source=linux/map_artifact_target.sh
    source "$ROOT/scripts/linux/map_artifact_target.sh"
    expected_artifact_target="$(map_linux_artifact_target "$ARCH")" || exit 1
    LINUX_ARTIFACT_TARGET=${LINUX_ARTIFACT_TARGET:-}
    case "$LINUX_ARTIFACT_TARGET" in
        linux_64|linux_arm64|linux_raspberrypi_arm64|linux_raspberrypi_armv6|linux_raspberrypi_armv7) ;;
        *)
            echo "Error: LINUX_ARTIFACT_TARGET must be an explicit supported Linux release target." >&2
            echo "Supported: linux_64 linux_arm64 linux_raspberrypi_arm64 linux_raspberrypi_armv6 linux_raspberrypi_armv7" >&2
            exit 1
            ;;
    esac
    if [ "$GCC" != "gcc10" ]; then
        echo "Error: Linux release archives must use the GCC 10 baseline (got '${GCC:-unset}')." >&2
        exit 1
    fi
    TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}_${GCC}.tar.bz2"
    if [ "$LINUX_ARTIFACT_TARGET" != "$expected_artifact_target" ]; then
        echo "Error: Linux target mapping '$LINUX_ARTIFACT_TARGET' does not match ARCH '$ARCH' ($expected_artifact_target)." >&2
        exit 1
    fi
    echo "TARBALL: [$TARBALL]"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct)}
    if tar --version 2>/dev/null | grep -q 'GNU tar'; then
        echo "cd ${OUTPUT_FOLDER}; deterministic tar -> $TARBALL"
        tar --sort=name --mtime="@${SOURCE_DATE_EPOCH}" --owner=0 --group=0 --numeric-owner -cjvf "$TARBALL" $LIBS
    else
        echo "Warning: deterministic release archives require GNU tar; creating a local validation archive." >&2
        tar cjvf "$TARBALL" $LIBS
    fi
    if [ $? -eq 0 ]; then
        echo "Successfully created tarball: $TARBALL"
    else
        echo "Error: Failed to create tarball."
        exit 1
    fi
    sha256sum "$TARBALL" > "${TARBALL}.sha256"
    cat > "${TARBALL}.manifest.json" <<EOF
{"schema":1,"artifact":"${TARBALL}","target":"${LINUX_ARTIFACT_TARGET}","compiler":"gcc10","architecture":"${ARCH}","source_date_epoch":${SOURCE_DATE_EPOCH}}
EOF
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
        elif [ "${VS_VER}" == "18" ]; then
            echo "VS2026 Version"
            TARGET="${TARGET}_2026"
        fi
    fi
    if [ -n "$PBUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}_${PBUNDLE}.zip"
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
    # fi
elif [ "$TARGET" == "android" ]; then
    TARBALL=openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${ARCH}.tar.bz2
    echo "TARBALL: [$TARBALL]"
    echo "tar cjf $TARBALL $LIBS"
    if [ "${EXIT_BEFORE}" == "1" ]; then
        exit 0
    fi
    tar cjvf $TARBALL $LIBS
elif [ "$TARGET" == "macos" ]; then
    if [ -n "$PBUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${PBUNDLE}.tar.bz2"
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
    if [ -n "$PBUNDLE" ]; then
        TARBALL="openFrameworksLibs_${CUR_BRANCH}_${TARGET}_${PBUNDLE}.tar.bz2"
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

echo "Packaged libs to upload [$TARBALL]"
echo "done "
pwd
find ./ -type f \( -name "*.zip" -o -name "*.tar.bz2" \) -exec echo {} \;
cd ../
