#!/usr/bin/env bash
set -e
set -o pipefail

TARGET=${TARGET:-""}
ARCH=${ARCH:-""}
OPT=${OPT:-""}
OUTPUT_FOLDER=${OUTPUT_FOLDER:-"/out"}
PARALLEL=${PARALLEL:-2}

if [ -z "$TARGET" ]; then
    echo "Error: TARGET not specified. Usage: $0 <target> <arch> [opt]"
    exit 1
fi
trapError() {
    echo "Error occurred during packaging. Check logs."
    exit 1
}
trap "trapError" ERR

package_library() {
    local LIB=$1
    local TARGET=$2
    local ARCH=$3
    local OPTS=$4

    echo "Packaging library: $LIB for target: $TARGET arch: $ARCH opts: $OPTS"

    local package_name="${LIB}_${TARGET}_${ARCH}$( [ -n "$OPTS" ] && echo "_${OPTS}")"    
    #local library_path="${OUTPUT_FOLDER}/${LIB}"
    local library_path="${LIB}"
    local TARBALL

    if [ ! -d "$library_path" ]; then
        echo "Error: Library directory '$library_path' does not exist."
        return 1
    fi

    # Determine the tarball or zip file name
    if [[ "$TARGET" == "msys2" ]]; then
        TARBALL="${OUTPUT_FOLDER}/${package_name}.zip"
        echo "Creating ZIP: $package_file_path"
        "C:\Program Files\7-Zip\7z.exe" a "$TARBALL" "$library_path"
    elif [[ "$TARGET" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        TARBALL="${OUTPUT_FOLDER}/${package_name}.tar.bz2"
        echo "Creating TAR.BZ2: $TARBALL"
        tar cjvf "$TARBALL" -C "$library_path"
    else
        TARBALL="${OUTPUT_FOLDER}/${package_name}.tar.gz"
        echo "Creating TAR.GZ: $TARBALL"
        tar czvf "$TARBALL" -C "$library_path"
    fi

    echo "Packaged Seperate: [$TARBALL]"
}

# Validate OUTPUT_FOLDER
if [ ! -d "$OUTPUT_FOLDER" ]; then
    echo "Error: Output folder '$OUTPUT_FOLDER' does not exist."
    exit 1
fi

# Get list of libraries
LIBRARIES=$(ls "$OUTPUT_FOLDER")
cd $OUTPUT_FOLDER;
LIBS=$(ls $OUTPUT_FOLDER)
LIBS=$(echo "$LIBS" | tr '\n' ' ')
if [ -z "$LIBRARIES" ]; then
    echo "No libraries found to package."
    exit 0
fi

# Process each library
echo "Libraries found: [$LIBS]"
echo "Packaging with TARGET=$TARGET, ARCH=$ARCH, OPTS=$OPTS"

for library in $LIBS; do
    package_library "$library" "$TARGET" "$ARCH" "$OPTS"
done

pwd
find out/ -type f \( -name "*.zip" -o -name "*.tar.bz2" \) -exec echo {} \;

echo "All libraries packaged successfully."
cd ../





