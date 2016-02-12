#!/bin/bash
NDK_DIR=android-ndk-r10e
set -ev
# capture failing exits in commands obscured behind a pipe
set -o pipefail
APOTHECARY_DIR=${TRAVIS_BUILD_DIR}/apothecary
cd ~
sudo apt-get update
sudo apt-get install -y premake4
# check if cached directory exists
if [ "$(ls -A ${NDK_DIR})" ]; then
    echo "Using cached NDK"
    ls -A ${NDK_DIR}
else
    echo "Downloading NDK"
    curl -Lk http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin -o ndk.bin
    chmod u+x ndk.bin
    echo "Uncompressing NDK"
    ./ndk.bin > /dev/null 2>&1 
fi
NDK_ROOT=$(echo ${PWD})
echo "APOTHECARY DIR set to $APOTHECARY_DIR"
echo "NDK_ROOT=${NDK_ROOT}/${NDK_DIR}" > $APOTHECARY_DIR/paths.make
cat $APOTHECARY_DIR/paths.make
