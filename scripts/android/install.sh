#!/usr/bin/env bash
set -e
APOTHECARY_PATH=$(
    cd $(dirname "$0")
    pwd -P
)/../../apothecary

sudo apt-get update
sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils libtool dos2unix
sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev ccache
sudo aptitude install -y gperf
