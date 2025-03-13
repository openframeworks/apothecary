#!/bin/bash

# Directory setup
ORIGINAL_DIR="$(pwd)"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$CURRENT_DIR"
APOTHECARY_LEVEL="$(cd "$CURRENT_DIR/.." && pwd)"

# Ensure out/ directory exists
if [ -d "$APOTHECARY_LEVEL/out" ]; then
    echo "out dir exists"
else
    echo "OUT_DIR does not exist. Creating it..."
    mkdir -p "$APOTHECARY_LEVEL/out"
fi

OUT_DIR="$(cd "$APOTHECARY_LEVEL/out" && pwd)"
cd "$OUT_DIR"

# Function to safely extract values from .pkl files
extract_value() {
    local pkl_file="$1"
    local key="$2"
    awk -F' *= *' -v key="$key" '$1 == key {gsub(/"/, "", $2); print $2}' "$pkl_file" | tr -d '\n'
}

# Template for .pc file with relative paths (used if generating a new file)
pc_template() {
    local libname="$1"
    local version="$2"
    local libs="$3"
    local defines="$4"
    local requires="$5"
    local frameworks="$6"
    cat <<EOF
prefix=\${pcfiledir}/../..
exec_prefix=\${pcfiledir}
libdir=\${pcfiledir}
includedir=\${pcfiledir}/../../../include

Name: $libname
Description: $libname library
Version: $version

Requires: $requires
Libs: $libs
Cflags: -I\${includedir} $defines
$frameworks
EOF
}

# Template for .cmake file with relative paths (used if generating a new file)
cmake_template() {
    local libname="$1"
    local version="$2"
    local LibName="$(echo "$libname" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
    local LIBNAME="$(echo "$libname" | tr '[:lower:]' '[:upper:]')"
    cat <<EOF
# Find${LibName}.cmake
# Version: $version (commented for documentation purposes)

find_path(${LIBNAME}_INCLUDE_DIR
    NAMES ${libname}.h
    PATHS "\${CMAKE_CURRENT_LIST_DIR}/../../../include"
    NO_DEFAULT_PATH
)

find_library(${LIBNAME}_LIBRARY
    NAMES ${libname}
    PATHS "\${CMAKE_CURRENT_LIST_DIR}"
    NO_DEFAULT_PATH
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(${LibName}
    REQUIRED_VARS ${LIBNAME}_INCLUDE_DIR ${LIBNAME}_LIBRARY
)

if(${LIBNAME}_FOUND)
    set(${LIBNAME}_INCLUDE_DIRS \${${LIBNAME}_INCLUDE_DIR})
    set(${LIBNAME}_LIBRARIES \${${LIBNAME}_LIBRARY})
endif()

mark_as_advanced(${LIBNAME}_INCLUDE_DIR ${LIBNAME}_LIBRARY)
EOF
}

# Process all .pkl files
find "$OUT_DIR" -type f -name "*.pkl" | while read -r pkl_file; do
    LIB_DIR="$(dirname "$pkl_file")"
    # Extract library name from .pkl file
    LIB_NAME=$(extract_value "$pkl_file" "name")

    if [ -z "$LIB_NAME" ]; then
        echo "Warning: No 'name' field found in $pkl_file, using directory name as fallback."
        LIB_NAME=$(basename "$LIB_DIR")
    fi

    echo "Processing $LIB_NAME ($pkl_file)..."

    # Extract metadata from .pkl
    version=$(extract_value "$pkl_file" "version")
    dependencies=$(extract_value "$pkl_file" "dependencies")
    defines=$(extract_value "$pkl_file" "defines")
    frameworks=$(extract_value "$pkl_file" "frameworks")

    # Default to "-" if values are empty
    version="${version:--}"
    dependencies="${dependencies:--}"
    defines="${defines:--}"
    frameworks="${frameworks:--}"

    # Clean defines to remove CMake-specific flags (e.g., -DCMAKE_C_STANDARD)
    if [ "$defines" != "-" ]; then
        defines=$(echo "$defines" | sed 's/-DCMAKE_[^ ]*//g' | tr -s ' ' | sed 's/^-//;s/ $//')
        [ -z "$defines" ] && defines=""
    else
        defines=""
    fi

    # Prepare dependencies and frameworks for .pc file
    if [ "$dependencies" != "-" ]; then
        requires="$dependencies"
    else
        requires=""
    fi
    if [ "$frameworks" != "-" ]; then
        framework_line="Frameworks: $frameworks"
    else
        framework_line=""
    fi

    # Find binaries (.a, .lib, .xcframework)
    while IFS= read -r binary_path; do
        if [ -n "$binary_path" ]; then
            BINARY_DIR="$(dirname "$binary_path")"
            BINARY_NAME=$(basename "$binary_path")

            # Determine platform-specific Libs and Frameworks
            libs=""
            if [[ "$BINARY_NAME" == *.a ]]; then
                libs="-L\${libdir} -l${LIB_NAME}"
            elif [[ "$BINARY_NAME" == *.lib ]]; then
                libs="-L\${libdir} ${LIB_NAME}.lib"
            elif [[ "$BINARY_NAME" == *.xcframework ]]; then
                libs="-L\${libdir} -l${LIB_NAME}"
                if [ "$frameworks" == "-" ]; then
                    framework_line="Frameworks: -framework ${LIB_NAME}"
                fi
            fi

            # Define paths for .pc and .cmake files
            PC_FILE="$BINARY_DIR/${LIB_NAME}.pc"
            CMAKE_FILE="$BINARY_DIR/Find$(echo "$LIB_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}').cmake"

            # Check if .pc file exists and update it, otherwise generate a new one
            if [ -f "$PC_FILE" ]; then
                echo "Existing .pc file found at $PC_FILE, updating paths to relative..."
                sed -i.bak "s|^prefix=.*|prefix=\${pcfiledir}/../..|" "$PC_FILE"
                sed -i.bak "s|^exec_prefix=.*|exec_prefix=\${pcfiledir}|" "$PC_FILE"
                sed -i.bak "s|^libdir=.*|libdir=\${pcfiledir}|" "$PC_FILE"
                sed -i.bak "s|^includedir=.*|includedir=\${pcfiledir}/../../../include|" "$PC_FILE"
                rm -v "$PC_FILE.bak"
            else
                echo "No existing .pc file found, generating $PC_FILE..."
                pc_template "$LIB_NAME" "$version" "$libs" "$defines" "$requires" "$framework_line" > "$PC_FILE"
            fi

            # Check if .cmake file exists and update it, otherwise generate a new one
            if [ -f "$CMAKE_FILE" ]; then
                echo "Existing .cmake file found at $CMAKE_FILE, updating include path to relative..."
                sed -i.bak "s|PATHS \".*\"|PATHS \"\${CMAKE_CURRENT_LIST_DIR}/../../../include\"|" "$CMAKE_FILE"
                rm -v "$CMAKE_FILE.bak"
            else
                echo "No existing .cmake file found, generating $CMAKE_FILE..."
                cmake_template "$LIB_NAME" "$version" > "$CMAKE_FILE"
            fi

            echo "Processed ${LIB_NAME}.pc and Find$(echo "$LIB_NAME" | awk '{print toupper(substr($0,1,1)) substr($0,2)}').cmake for $LIB_NAME at $BINARY_DIR"
        fi
    done < <(find "$LIB_DIR" -type f \( -name "*.a" -o -name "*.lib" \) -o -type d -name "*.xcframework")
done

# Return to original directory
cd "$ORIGINAL_DIR"