#!/usr/bin/env bash
set -e

sudo dpkg --add-architecture arm64
sudo apt update
sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils
sudo aptitude install -y gperf
sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev
sudo apt-get install -y ccache
sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

dpkg -L gcc-aarch64-linux-gnu
sudo apt install libgl1-mesa-dev:arm64 libgles2-mesa-dev:arm64



if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    find /usr/lib/x86_64-linux-gnu -name "libGL*"

    lib_files=$(find /usr/lib/x86_64-linux-gnu -name "libGL*")

    if [ -z "$lib_files" ]; then
        echo "No libGL* files found in /usr/lib/x86_64-linux-gnu"
        exit 1
    fi
    echo -e "\n\033[1;32m==== Running ldd on libGL* files ====\033[0m"
    for file in $lib_files; do
        echo -e "\n\033[1;34mFile: $file\033[0m"
        ldd "$file" || echo "Error: Could not run ldd on $file"
    done
fi
if [ -d "/usr/lib/aarch64-linux-gnu" ]; then
    find /usr/lib/aarch64-linux-gnu -name "libGL*"
else
    echo "Directory /usr/lib/aarch64-linux-gnu does not exist."
fi
