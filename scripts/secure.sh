#!/usr/bin/env bash
set -e

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

# Get current date and time in ISO 8601 format
BUILD_TIME=$(date -u +"%Y-%m-%d T%H:%M:%SZ")

# Check if git is available and repository exists
if command -v git &>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    # Get the current Git commit hash
    GIT_HASH=$(git rev-parse HEAD)

    # Get the current Git branch
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
else
    GIT_HASH="N/A"
    GIT_BRANCH="N/A"
fi



if [ -z "${BINARY_SEC+x}" ]; then
    BINARY_SEC=${2:-}
fi

if [ -z "${VERSION+x}" ]; then
    VERSION=${2:-}
fi

secure() { 
BINARY_SEC=$1
OUTPUT_LOCATION=$(dirname "$BINARY_SEC")
FILENAME=$(basename "$BINARY_SEC")

echo "OUTPUT_LOCATION: $OUTPUT_LOCATION"

# Calculate SHA hash for the provided binary, if available
BINARY_SHA=$(calculate_hash "$BINARY_SEC")

OUTPUT_FILE="${OUTPUT_LOCATION:-.}/version.json"

# Create or overwrite the version.json file
cat <<EOF > "$OUTPUT_FILE"
{
  "buildTime": "$BUILD_TIME",
  "gitHash": "$GIT_HASH",
  "gitBranch": "$GIT_BRANCH",
  "gitUrl": "$GIT_URL",
  "binarySha": "$BINARY_SHA",
  "binary": "$FILENAME",
  "version": "$VER",
}
EOF
cat "$OUTPUT_FILE"

OUTPUT_PKL_FILE="${OUTPUT_LOCATION:-.}/version.pkl"

# Create or overwrite the version.json file
cat <<EOF > "$OUTPUT_PKL_FILE"
buildTime = "$BUILD_TIME"
gitHash = "$GIT_HASH"
gitBranch = "$GIT_BRANCH"
gitUrl = "$GIT_URL"
binarySha = "$BINARY_SHA"
binary = $FILENAME"
version = "$VER"
EOF
cat "$OUTPUT_PKL_FILE"

}
