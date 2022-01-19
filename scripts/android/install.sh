#!/usr/bin/env bash
set -e
APOTHECARY_PATH=$(cd $(dirname "$0"); pwd -P)/../../apothecary

sudo apt-get update -q
sudo apt-get remove mssql-tools 2> /dev/null # this is because mysql-tools includes a program called bcp which conflicts with boosts bcp
sudo apt-get install -y libboost-tools-dev gperf

sudo apt remove --purge --auto-remove cmake

# from https://apt.kitware.com - to get latest cmake
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null

sudo apt-add-repository 'deb https://apt.kitware.com/ubuntu/ xenial main'
sudo apt update
sudo apt install -y cmake
cmake --version

NDK_VERSION="r23b"
export NDK_ROOT="$(realpath ~/)/android-ndk-${NDK_VERSION}/"

# Check if cached NDK directory exists
if [ "$(ls -A ${NDK_ROOT})" ]; then
    echo "Using cached NDK"
    ls -A ${NDK_ROOT}
else
    cd ~/
    echo "Downloading NDK $NDK_VERSION"
    wget -q --no-check-certificate https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
    echo "Uncompressing NDK"
    unzip android-ndk-${NDK_VERSION}-linux.zip > /dev/null 2>&1
    rm android-ndk-${NDK_VERSION}-linux.zip
    echo "NDK installed at $NDK_ROOT"
    cd -
fi

echo "NDK_ROOT=${NDK_ROOT};" > ${APOTHECARY_PATH}/paths.make

