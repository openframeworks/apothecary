#!/bin/bash

# usage 
# ."$SCRIPT_DIR/save.sh"
# save "ios" "freeimage" "arm64" "true" "v9.1.0" "v9.1.0"

# Function to save build information to a text file
function save {

    # Check if the save file exists
    SAVE_FILE="$SCRIPT_DIR/build_status.txt"
    if [ ! -f ./$SAVE_FILE ]; then
        touch ./$SAVE_FILE
    fi

    # Get input parameters
    DEVICE_TARGET="$1"
    SOURCE_TARGET="$2"
    ARCH="$3"
    BUILT="$4"
    VERSION="$5"
    TAG="$6"
    
    # Get current date and time
    BUILD_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Create new or update existing entry in the text file
    # Only one unique entry for each device target, source target, and architecture
    # Format: DEVICE_TARGET|SOURCE_TARGET|ARCH|BUILT|VERSION|TAG|BUILD_DATETIME
    if grep -q "$DEVICE_TARGET|$SOURCE_TARGET|$ARCH" "$SCRIPT_DIR/build_info.txt"; then
        sed -i '' "s|$DEVICE_TARGET|$DEVICE_TARGET|$SOURCE_TARGET|$ARCH|.*|$DEVICE_TARGET|$SOURCE_TARGET|$ARCH|$BUILT|$VERSION|$TAG|$BUILD_DATETIME|" "SAVE_FILE"
    else
        echo "$DEVICE_TARGET|$SOURCE_TARGET|$ARCH|$BUILT|$VERSION|$TAG|$BUILD_DATETIME" >> "$SAVE_FILE"
    fi
}

