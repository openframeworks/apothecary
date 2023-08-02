#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail


BUNDLE_NO="$1"
# Check if the argument is provided
if [ -z "${BUNDLE_NO+x}" ]; then
    echo "No argument provided."
    export BUNDLE=1
else
    echo "Argument 1: $BUNDLE_NO"
    export BUNDLE=$BUNDLE_NO
fi

export TARGET=vs
export ARCH=64
export NO_FORCE=ON
export VS_VER=17

echo "Target: $TARGET"
echo "Architecture: $ARCH"
echo "Bundle: $BUNDLE"
echo "Apothecary path: $MAIN_PATH"

mkdir -p out
ls
pwd
./scripts/build.sh

