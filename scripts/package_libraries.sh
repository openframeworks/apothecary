#!/usr/bin/env bash
set -e
set -o pipefail

TARGET=${1:-"unknown"}
ARCH=${2:-"unknown"}
OPT=${3:-""}
OUTPUT_FOLDER=${OUTPUT_FOLDER:-"./out"}
PARALLEL=${PARALLEL:-2}

if [ -z "$TARGET" ] || [ "$TARGET" == "unknown" ]; then
    echo "Error: TARGET not specified. Usage: $0 <target> <arch> [opt]"
    exit 1
fi
trapError() {
    echo "Error occurred during packaging. Check logs."
    exit 1
}
trap "trapError" ERR

package_library() {
    local library_name=$1
    local target=$2
    local arch=$3
    local opts=$4
    echo "Packaging library: $library_name for target: $target arch: $arch opts: $opts"
    local package_name=""
    if [ -n "$opts" ]; then
	    package_name="${library_name}_${target}_${arch}_${opts}"
	else
	    package_name="${library_name}_${target}_${arch}"
	fi
    local library_path="${OUTPUT_FOLDER}/${library_name}"
    local package_file_path

    if [ ! -d "$library_path" ]; then
        echo "Error: Library directory '$library_path' does not exist."
        return 1
    fi

    if [[ "$target" == "vs" ]]; then
        package_file_path="${OUTPUT_FOLDER}/${package_name}.zip"
        (cd "$library_path" && zip -r "../${package_name}.zip" .)
        echo "Created ZIP: $package_file_path"
    else
        package_file_path="${OUTPUT_FOLDER}/${package_name}.tar.gz"
        tar czvf "$package_file_path" -C "$library_path" .
        echo "Created TAR.GZ: $package_file_path"
    fi

    rm -rf "$package_path"
}
if [ ! -d "$OUTPUT_FOLDER" ]; then
    echo "Error: Output folder '$OUTPUT_FOLDER' does not exist."
    exit 1
fi

LIBRARIES=$(ls "$OUTPUT_FOLDER")
if [ -z "$LIBRARIES" ]; then
    echo "No libraries found to package."
    exit 0
fi

echo "Libraries found: $LIBRARIES"
echo "Packaging with TARGET=$TARGET, ARCH=$ARCH, OPTs=$OPT"
for library in $LIBRARIES; do
    package_library "$library" "$TARGET" "$ARCH"
done

echo "All libraries packaged successfully."
