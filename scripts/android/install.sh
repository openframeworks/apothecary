#!/bin/bash
NDK_DIR=android-ndk-r10e
set -ev
# capture failing exits in commands obscured behind a pipe
set -o pipefail
APOTHECARY_DIR=${TRAVIS_BUILD_DIR}/apothecary
cd ~
# check if cached directory exists
if [ "$(ls -A ${NDK_DIR})" ]; then
    echo "Using cached NDK"
    ls -A ${NDK_DIR}
else
    echo "Downloading NDK"
    curl -Lk http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin -o ndk.bin
    chmod u+x ndk.bin
    ./ndk.bin
fi
NDK_ROOT=$(echo ${PWD})
echo "APOTHECARY DIR set to $APOTHECARY_DIR"
echo "NDK_ROOT=${NDK_ROOT}/${NDK_DIR}" > $APOTHECARY_DIR/paths.make
cat $APOTHECARY_DIR/paths.make
