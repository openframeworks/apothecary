#!/usr/bin/env bash
set -e

echo "--- Installing extra depends --- "

sudo apt-get -y install libasound-dev libjack-dev libpulse-dev oss4-dev #rtaudio
# sudo apt-get update && sudo apt-get install -y autoconf libtool automake dos2unix
# sudo apt-get update && sudo apt-get install -y cmake build-essential
# sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev cmake build-essential libc6-dev
# sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils libtool dos2unix
# sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev ccache
# sudo apt-get install -y gperf

# dpkg -L gcc-aarch64-linux-gnu
# sudo apt-get install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu

dpkg -L gcc-aarch64-linux-gnu

echo "--- Output usr/lib/* --- "
# if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
#     find /usr/lib/x86_64-linux-gnu -name "libGL*"
# fi
# if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
#     find /usr/lib/x86_64-linux-gnu -name "libGL*"
# fi

# Verify the installation
cmake --version
