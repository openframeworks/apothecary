#!/bin/bash

# usage 
# ."$SCRIPT_DIR/save.sh"
# load "ios" "freeimage" "arm64" "true" "v9.1.0" "v9.1.0"
set +e

function loadsave() {
  if [ -z "$2" ]; then
    echo "Load function not implemented - Param error"
    echo 0
  fi
  local LOCAL_SAVE_FILE="$5"
  #SAVE_FILE="$SCRIPT_DIR/build_status.txt"
  # Get the input parameters
  local device_target="$1"
  local source_target="$2"
  local arch="$3"
  local version="$4"
  local pkldir="$5"
  local buildInfo="$6"

  BINARY_SEC=${pkldir}
  #OUTPUT_LOCATION=$(dirname "$BINARY_SEC")
  FILENAME=$(basename "$BINARY_SEC/$2.pkl")
  FILENAME_WITHOUT_EXT="${FILENAME%.*}"
  OUTPUT_PKL_FILE="${BINARY_SEC:-.}/$FILENAME_WITHOUT_EXT.pkl"

  #echo " BINARY_SEC:[$BINARY_SEC] load file: [$OUTPUT_PKL_FILE] [0:$0 1:$1 2:$2 3:$3 4:$4]"
  #echo " FILENAME: [$FILENAME] [FILENAME_WITHOUT_EXT:$FILENAME_WITHOUT_EXT OUTPUT_PKL_FILE:$OUTPUT_PKL_FILE]"

  # if [[ ! -f "$LOCAL_SAVE_FILE" ]]; then
  #     touch $LOCAL_SAVE_FILE
  #     return 1
  # fi

  if [[ ! -d "$BINARY_SEC" ]]; then
    echo " Build confirmed for $1 [No cached $BINARY_SEC]"
    echo 0
    return 0
  fi

   if [[ ! -f "$OUTPUT_PKL_FILE" ]]; then
    echo " Build confirmed for $1 [No cached previous output PKL: $OUTPUT_PKL_FILE]"
    echo 0
    return 0
  fi

  # Read and parse the .pkl file
  local buildTime=$(grep 'buildTime =' "$OUTPUT_PKL_FILE" | cut -d '"' -f 2)
  local fileVersion=$(grep 'version =' "$OUTPUT_PKL_FILE" | cut -d '"' -f 2)

  if grep -q 'buildNumber =' "$OUTPUT_PKL_FILE"; then
    local buildNumber=$(grep 'buildNumber =' "$OUTPUT_PKL_FILE" | cut -d '"' -f 2)
  else
    local buildNumber=1
  fi

  if [[ "$fileVersion" != "$version" ]]; then
    echo " Build confirmed. Previous build has Version mismatch: $fileVersion != $version"
    echo 0
    return 0
  fi

  if [[ "${buildNumber}" != "" && "${buildInfo}" != "${buildNumber}" ]]; then
    echo " Build confirmed. Previous build number has mismatch: $buildInfo != $buildNumber"
    echo 0
    return 0
  fi

  # Check if the entry needs to be rebuilt based on buildTime
  # local now=$(date -u +%s)
  # if [[ $(uname) == "Darwin" ]]; then
  #   local saved=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$buildTime" +%s)
  # else
  #   local saved=$(date -d "$buildTime" +%s)
  # fi
  # local diff=$(( (now - saved) / (60 * 60 * 24) ))

  # if [[ "$buildTime" == "false" || "$diff" -ge 90 ]]; then
  #   echo " Build confirmed. Previous Build time is older than 90 days (${diff}) - Rebuilding"
  #   echo 0
  #   return 0
  # fi

  # Entry exists and doesn't need to be rebuilt
  # echo " Build skipped. $2 past output is all up to date. $version built at : $saved"
  echo 1
  return 0

}
