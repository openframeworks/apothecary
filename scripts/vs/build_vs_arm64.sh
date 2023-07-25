#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail


export TARGET=vs
export ARCH=arm64
export BUNDLE=2

echo "Target: $TARGET"
echo "Architecture: $ARCH"
echo "Bundle: $BUNDLE"
echo "Apothecary path: $MAIN_PATH"


ls
pwd
./scripts/build.sh

