#!/usr/bin/env bash
set +e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Function to calculate SHA for security
calculate_hash() {
    local file=$1
    if [[ -f "$file" ]]; then
        if command -v sha256sum &>/dev/null; then
            sha256sum "$file" | awk '{print $1}'
        elif command -v sha1sum &>/dev/null; then
            sha1sum "$file" | awk '{print $1}'
        elif command -v sha512sum &>/dev/null; then
            sha512sum "$file" | awk '{print $1}'
        elif command -v md5sum &>/dev/null; then
            md5sum "$file" | awk '{print $1}'
        elif command -v md5 &>/dev/null; then
            md5 -q "$file"
        else
            echo "No suitable hash function found."
        fi
    else
        echo "N/A"
    fi
}
hash_type() {
    if command -v sha256sum &>/dev/null; then
        echo "sha256sum"
    elif command -v sha1sum &>/dev/null; then
        echo "sha1sum"
    elif command -v sha512sum &>/dev/null; then
        echo "sha512sum"
    elif command -v md5sum &>/dev/null; then
        echo "md5sum"
    elif command -v md5 &>/dev/null; then
        echo "md5"
    else
        echo "void"
    fi
}

# Get current date and time in ISO 8601 format
BUILD_TIME=$(date -u +"%Y-%m-%d T%H:%M:%SZ")

# Check if git is available and repository exists
# if command -v git &>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
#     # Get the current Git commit hash
#     GIT_HASH=$(git rev-parse HEAD)

#     # Get the current Git branch
#     GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
# else
#     GIT_HASH="N/A"
#     GIT_BRANCH="N/A"
# fi

if [ -z "${BINARY_SEC+x}" ]; then
    BINARY_SEC=${1:-}
fi
if [ -z "${VERSION+x}" ]; then
    VERSION=${3:-}
fi

if [ -z "${DEFINES+x}" ]; then
    DEFS=${4:-}
fi

if [ -z "${FORMULA_DEPENDS+x}" ]; then
    FORMULA_DEPENDS=${6:-}
fi

if [ -z "${FRAMEWORKS+x}" ]; then
    FRAMEWORKS=${8:-}
fi

secure() { 
    if [ -z "${1+x}" ]; then
        BINARY_SEC=""
    else
        BINARY_SEC=$1
    fi

    if [ -z "${4+x}" ]; then
        DEFS=""
    else
        DEFS=$4
    fi

    if [ -z "${5+x}" ]; then
        BUILD_NUMBER=1
    else
        BUILD_NUMBER=$5
    fi

    if [ -z "${FORMULA_DEPENDS+x}" ]; then
        if [ -z "${6+x}" ]; then
            FORMULA_DEPENDS=""
        else
            FORMULA_DEPENDS=$6
        fi
    fi

    if [[ ! -z "${VS_C_FLAGS+x}" && ! -z "${FLAGS_RELEASE+x}" && ! -z "${EXCEPTION_FLAGS+x}" ]]; then
        FLAGS="${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}"
    elif [[ ! -z "${FLAG_RELEASE+x}" ]]; then
        FLAGS="${FLAG_RELEASE}"
    else
        FLAGS=""
    fi

    if [ -z "${7+x}" ]; then
        SOURCE_SHA=""
    else
        SOURCE_SHA=$7
    fi

    if [ -z "${8+x}" ]; then
        FRAMEWORKS=""
    else
        FRAMEWORKS=$8
    fi

    OUTPUT_LOCATION=$(dirname "$BINARY_SEC")
    ACTUAL_FILENAME=$(basename "$BINARY_SEC")
    ACTUAL_FILENAME_WITHOUT_EXT="${ACTUAL_FILENAME%.*}"

    if [ -z "${2+x}" ]; then NAME=$ACTUAL_FILENAME_WITHOUT_EXT; else
        NAME=$2
        NAME="${NAME%.*}"
    fi

    if [ -z "${DEFS+x}" ]; then DEFINES=""; else
        DEFINES=$DEFS
    fi

    if [ -z "${TYPE+x}" ]; then TARGET=""; else
        TARGET=$TYPE
    fi

    HASH_TYPE=$(hash_type "$BINARY_SEC")
    
    if [ -n "$NAME" ]; then
        FILENAME="$NAME"
    else
        FILENAME="$ACTUAL_FILENAME"
    fi

    CPP_STD="$CPP_STANDARD"
    C_STD="$C_STANDARD"

    FILENAME_WITHOUT_EXT="${FILENAME%.*}"

    # Calculate SHA hash for the provided binary, if available
    BINARY_SHA=$(calculate_hash "$BINARY_SEC")
    # OUTPUT_FILE="${OUTPUT_LOCATION:-.}/$FILENAME_WITHOUT_EXT.json"
    #
    # Create or overwrite the .json file
    # cat <<EOF > "$OUTPUT_FILE"
    # {
    #   "buildTime": "$BUILD_TIME",
    #   "gitHash": "$GIT_HASH",
    #   "gitBranch": "$GIT_BRANCH",
    #   "gitUrl": "$GIT_URL",
    #   "binarySha": "$BINARY_SHA",
    #   "binary": "$FILENAME",
    #   "version": "$VER",
    # }
    # EOF
    # cat "$OUTPUT_FILE"
    OUTPUT_PKL_FILE="${OUTPUT_LOCATION:-.}/$FILENAME_WITHOUT_EXT.pkl"
# Create or overwrite the .pkl file - Pkl simple Key = Value
cat <<EOF > "$OUTPUT_PKL_FILE"
name = "$NAME"
version = "$VER"
buildTime = "$BUILD_TIME"
buildNumber = "$BUILD_NUMBER"
type = "$TARGET"
gitUrl = "$GIT_URL"
cppStandard = "$CPP_STD"
cStandard = "$C_STD"
linkerFlags = "$FLAGS"
dependencies = "$FORMULA_DEPENDS"
binary = "$ACTUAL_FILENAME"
binarySha = "$BINARY_SHA"
shaType = "$HASH_TYPE"
sourceSHA = "$SOURCE_SHA"
defines = "$DEFINES"
frameworks = "$FRAMEWORKS"
EOF
cat "$OUTPUT_PKL_FILE"

}
