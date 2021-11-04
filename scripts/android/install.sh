#!/usr/bin/env bash
set -e
APOTHECARY_PATH=$(cd $(dirname "$0"); pwd -P)/../../apothecary

sudo apt-get update -q
sudo apt-get remove mssql-tools 2> /dev/null # this is because mysql-tools includes a program called bcp which conflicts with boosts bcp
sudo apt-get install -y libboost-tools-dev gperf

NDK_VERSION="r15c"
NDK_ROOT="$(realpath ~/)/android-ndk-${NDK_VERSION}/"

# Check if cached NDK directory exists
if [ "$(ls -A ${NDK_ROOT})" ]; then
    echo "Using cached NDK"
    ls -A ${NDK_ROOT}
else
    cd ~/
    echo "Downloading NDK"
    wget -q --no-check-certificate https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux-x86_64.zip
    echo "Uncompressing NDK"
    unzip android-ndk-${NDK_VERSION}-linux-x86_64.zip > /dev/null 2>&1
    rm android-ndk-${NDK_VERSION}-linux-x86_64.zip
    echo "NDK installed at $NDK_ROOT"
    cd -
fi

echo "NDK_ROOT=${NDK_ROOT}" > ${APOTHECARY_PATH}/paths.make

