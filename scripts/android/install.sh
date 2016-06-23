#!/bin/bash
NDK_DIR=android-ndk-r12b
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
    curl -Lk http://dl.google.com/android/ndk/android-ndk-r12b-linux-x86_64.bin -o ndk.bin
    chmod u+x ndk.bin
    echo "Uncompressing NDK"
    ./ndk.bin > /dev/null 2>&1 
fi
NDK_ROOT=$(echo ${PWD})
echo "APOTHECARY DIR set to $APOTHECARY_DIR"
