#!/bin/bash
NDK_DIR=android-ndk-r10e
set -ev
# capture failing exits in commands obscured behind a pipe
set -o pipefail
ROOT=${TRAVIS_BUILD_DIR:-"$( cd "$(dirname "$0")/../.." ; pwd -P )"}
cd ~
# check if cached directory exists
if [ "$(ls -A ${NDK_DIR})" ]; then
    echo "Using cached NDK"
    ls -A ${NDK_DIR}
else
    echo "Downloading NDK"
    # curl -Lk http://dl.google.com/android/ndk/android-ndk-r10e-linux-x86_64.bin -o ndk.bin
    # get slimmed and recompressed NDK from our server instead
    curl -LO http://ci.openframeworks.cc/${NDK_DIR}.tar.bz2
    # extract customized NDK:
    tar -xjf ${NDK_DIR}.tar.bz2
    rm ${NDK_DIR}.tar.bz2
fi
NDK_ROOT=$(echo ${PWD} | sed "s/\//\\\\\//g")
echo "NDK_ROOT=${NDK_ROOT}/${NDK_DIR}" > $ROOT/paths.default.make
