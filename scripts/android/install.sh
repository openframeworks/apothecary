#!/usr/bin/env bash
export NDK_DIR=android-ndk-r15c
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
    echo "Downloading NDK $NDK_DIR"
    wget "https://dl.google.com/android/repository/$NDK_DIR-linux-x86_64.zip"
    echo "Uncompressing NDK"
    unzip "$NDK_DIR-linux-x86_64.zip" > /dev/null 2>&1 
fi
export NDK_ROOT=$(echo ${PWD})
echo "APOTHECARY DIR set to $APOTHECARY_DIR"
echo "NDK_ROOT=${NDK_ROOT}/${NDK_DIR}" > $APOTHECARY_DIR/paths.make
cat $APOTHECARY_DIR/paths.make
