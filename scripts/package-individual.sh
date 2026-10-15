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
GCC="${GCC:-}"
OPT="${OPT:-}"
GCC="${GCC:+_$GCC}"
OPT="${OPT:+_$OPT}"
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

if [ -n "${PACKAGE_LIBS:-}" ]; then
    # Package addon/non-core staging directories without adding them to the
    # core build matrix.
    IFS=', ' read -r -a FORMULAS <<< "$PACKAGE_LIBS"
    echo "Using explicitly requested modular libraries: [${FORMULAS[*]}]"
else
    echo "Sourcing: ${LOCAL_ROOT}/scripts/calculate_formulas.sh"
    source "${LOCAL_ROOT}/scripts/calculate_formulas.sh"
fi
if [ -z "$FORMULAS" ]; then
    echo "No formulas to build"
    exit 0
fi
if ! type formula_is_internal >/dev/null 2>&1; then
    formula_is_internal() { return 1; }
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

echo "Compressing individual libraries from [$OUTPUT_FOLDER]... FORMULAS:[$FORMULAS]"

package_failed=0
for LIB in "${FORMULAS[@]}"; do
    LIB=$(echo "$LIB" | tr -d '[:space:]')  # Remove all whitespace
    echo "Loop: [$LIB]"
    # pkg-config is a host build tool, not a downloadable library output.
    if [ "$LIB" = "pkg-config" ]; then
        echo "Skipping host tool '$LIB'"
        continue
    fi
    if formula_is_internal "$LIB"; then
        echo "Skipping internal formula '$LIB' (merged into curl)"
        continue
    fi
    if [ -d "$LIB" ]; then
        if [[ "$TARGET" == "msys2" || "$TARGET" == "vs" ]]; then
            # ZIP format for Windows (msys2 / vs)
            TARBALL="oF_${LIB}_${TARGET}_${ARCH}${OPT}.zip"
            echo "Packaging $LIB -> $TARBALL"
            if [[ "$TARGET" == "msys2" ]]; then
                "C:\Program Files\7-Zip\7z.exe" a "$TARBALL" "$LIB"
            else
                "C:\Program Files\7-Zip\7z.exe" a "$TARBALL" "$LIB"
            fi
        else
            # TAR format for Linux/macOS/Emscripten
            TARBALL="oF_${LIB}_${TARGET}_${ARCH}${GCC}${OPT}.tar.bz2"
            echo "Packaging $LIB -> $TARBALL"
            tar cjvf "$TARBALL" "$LIB"
        fi

        if [ $? -eq 0 ]; then
            echo "Successfully created package: $TARBALL"
        else
            echo "Error: Failed to package $LIB"
            package_failed=1
        fi
    else
        echo "Error: Cannot package $LIB as it does not exist in $OUTPUT_FOLDER"
        package_failed=1
    fi
done

echo "All libraries have been packaged."
echo "Listing all created packages:"
find . -type f -name "*.tar.bz2"

cd ../

exit "$package_failed"
