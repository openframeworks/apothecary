#!/usr/bin/env bash
NDK_VERSION="r15c"
NDK_ROOT="~/android-ndk-${NDK_VERSION}"

set -e

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

echo "NDK_ROOT=${NDK_ROOT}" > paths.make

# Install cmake for android
add-apt-repository ppa:dns/gnu -y
apt-get update -q
apt-get install -y --only-upgrade autoconf
apt-get install -y xutils-dev coreutils realpath libboost-tools-dev gperf
chmod +x ./scripts/android/install-cmake.sh
./scripts/android/install-cmake.sh -d -v 3.6.3155560 -p linux
echo "Installed cmake"
cmake --version