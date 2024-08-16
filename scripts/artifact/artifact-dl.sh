#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

if [ -z "${NO_FORCE+x}" ]; then
    export FORCE="-f"
else
    export FORCE=""
fi

OWNER="openframeworks"
REPO="apothecary"
PER_PAGE=9
OUTPUT_DIR="./out"

TOKEN="$1"
# Check if the argument is provided
if [ -z "${TOKEN+x}" ]; then
    echo "No Github token argument provided. Required for Artifacts - even from public please pass in like ./scripts/artifact-dl.sh github_pat_1147"
    echo "https://github.com/settings/tokens?type=beta"
    exit 1
else
    echo "Github token set!"
fi

# Ensure the output directory exists
mkdir -p "${OUTPUT_DIR}"

# Fetch the list of artifacts without a token
ARTIFACTS=$(curl -H "Accept: application/vnd.github.v3+json" "https://api.github.com/repos/${OWNER}/${REPO}/actions/artifacts?per_page=${PER_PAGE}")

echo "${ARTIFACTS}" | jq -r '.artifacts[] | "\(.id) \(.name)"' | while read -r id name; do
    echo "Attempting to download artifact ${name} with id ${id} with auth token..."
    DOWNLOAD_URL="https://api.github.com/repos/${OWNER}/${REPO}/actions/artifacts/${id}/zip"
    OUTPUT_FILE="${OUTPUT_DIR}/${name}.zip"
    
    if [[ -f "$OUTPUT_FILE" ]]; then
        echo "File ${name}.zip already exists in ${OUTPUT_DIR}. Skipping download."
    else
        curl -L -o "${OUTPUT_DIR}/${name}.zip" -H "Authorization: token ${TOKEN}" -H "Accept: application/vnd.github.v3+json" "${DOWNLOAD_URL}"
        
        echo "Attempted download of ${name} to ${OUTPUT_DIR}/${name}.zip"
    fi
done

echo "Attempt to download all artifacts with auth token complete."
