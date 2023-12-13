#!/bin/bash

# usage 
# ."$SCRIPT_DIR/save.sh"
# load "ios" "freeimage" "arm64" "true" "v9.1.0" "v9.1.0"


function loadsave() {

  if [ -z "$2" ]; then
    #echo "Load function not implemented - Param error"
    return 1
  fi

  echo "load file: $SAVE_FILE 0:$0 1:$1 2:$2 3:$3 4:$4 5:$5 "
  local LOCAL_SAVE_FILE="$5"
  #SAVE_FILE="$SCRIPT_DIR/build_status.txt"
  # Get the input parameters
  local device_target="$1"
  local source_target="$2"
  local arch="$3"
  local version="$4"
  #local tag="$5"


   # Check if the file exists
   if [[ ! -f "$LOCAL_SAVE_FILE" ]]; then
        touch $LOCAL_SAVE_FILE
        return 1
   fi

  # Search for the entry in the file
  local entry=$(grep "^$device_target|$source_target|$arch|$version|" "$LOCAL_SAVE_FILE")

  if [[ -z "$entry" ]]; then
    # Entry doesn't exist in the file
    return 1
  fi

  # Parse the entry
  local built=$(echo "$entry" | cut -d "|" -f 5)
  local datetime=$(echo "$entry" | cut -d "|" -f 6)

  # Check if the entry needs to be rebuilt
  local now=$(date -u +%s)
  if [[ $(uname) == "Darwin" ]]; then
    local saved=$(date -ju -f "%Y-%m-%d %H:%M:%S" "$datetime" +%s)
  else
    local saved=$(date -u -d "$datetime" +%s)
  fi
  local diff=$(( (now - saved) / (60 * 60 * 24) ))

  if [[ "$built" == "false" || "$diff" -ge 90 ]]; then
    return 1
  fi

  # Entry exists and doesn't need to be rebuilt
  return 0
}