#!/bin/bash

set -e

# # Script execution starts here
# TARGET_DIR="$1"
# PLATFORM="$2"
# ARCH="$3"

# Rewrite the paths
# export_paths "$TARGET_DIR" "$PLATFORM" "$ARCH"

# Function to rewrite paths in pkg-config and CMake files to be relative
export_paths() {
    local TARGET_DIR="$1"
    local PLATFORM="$2"
    local ARCH="$3"

    # Ensure the directories exist
    if [ -d "$TARGET_DIR/lib/$PLATFORM/$ARCH" ]; then
        echo "Rewriting pkg-config files in $TARGET_DIR/lib/$PLATFORM/$ARCH/pkgconfig..."

        for PKG_FILE in "$TARGET_DIR/lib/$PLATFORM/$ARCH"/*.pc; do
            [ -f "$PKG_FILE" ] || continue
            sed -i.bak "s|^prefix=.*|prefix=../../../|" "$PKG_FILE"
            sed -i.bak "s|^exec_prefix=.*|exec_prefix=../../../|" "$PKG_FILE"
            sed -i.bak "s|^libdir=.*|libdir=../|" "$PKG_FILE"
            sed -i.bak "s|^includedir=.*|includedir=../../../include|" "$PKG_FILE"
            rm "${PKG_FILE}.bak" # Clean up backup file
        done
    fi

    # Rewriting paths in CMake files (if applicable)
    if [ -d "$TARGET_DIR/lib/$PLATFORM/$ARCH" ]; then
        echo "Rewriting CMake files in $TARGET_DIR/lib/$PLATFORM/$ARCH/cmake..."

        for CMAKE_FILE in "$TARGET_DIR/lib/$PLATFORM/$ARCH"/*.cmake; do
            [ -f "$CMAKE_FILE" ] || continue
            sed -i.bak "s|${TARGET_DIR}|../../../|" "$CMAKE_FILE"
            rm "${CMAKE_FILE}.bak" # Clean up backup file
        done
    fi

    echo "Paths have been successfully rewritten for $PLATFORM/$ARCH."
}

# Ensure arguments are provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <TARGET_DIR> <PLATFORM> <ARCH>"
    exit 1
fi
