#!/bin/bash
NDK_VER=r12b
NDK_DIR="android-ndk-$NDK_VER"
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
    curl -Lk "http://dl.google.com/android/repository/android-ndk-$NDK_VER-linux-x86_64.zip" -o ndk.zip
    echo "Uncompressing NDK"
    unzip ndk.zip
fi
NDK_ROOT=$(echo ${PWD})
echo "APOTHECARY DIR set to $APOTHECARY_DIR"
