#!/bin/bash
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"

sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils
sudo aptitude install -y gperf
sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev
sudo apt-get install -y ccache
sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
sudo apt-get install \
    libboost-iostreams1.83.0:arm64 \
    libcwidget4:arm64 \
    libsigc++-2.0-0v5:arm64 \
    libxapian30:arm64 \
    libasound2-plugins:arm64 \
    libosmesa6:arm64 \
    libpcsclite1:arm64 \
    libspeexdsp1:arm64 \
    libwine:arm64 \
    libxkbregistry0:arm64 \
    libz-mingw-w64:arm64 \
    wine:arm64 \
    wine64:arm64 \
    wget2:arm64 \
    make:arm64 \
    libjack-jackd2-0:arm64 \
    libjack-jackd2-dev:arm64 \
    freeglut3-dev:arm64 \
    libasound2-dev:arm64 \
    libxmu-dev:arm64 \
    libxxf86vm-dev:arm64 \
    g++:arm64 \
    libgl1-mesa-dev:arm64 \
    libglu1-mesa-dev:arm64 \
    libraw1394-dev:arm64 \
    libudev-dev:arm64 \
    libdrm-dev:arm64 \
    libglew-dev:arm64 \
    libopenal-dev:arm64 \
    libsndfile1-dev:arm64 \
    libfreeimage-dev:arm64 \
    libcairo2-dev:arm64 \
    libfreetype6-dev:arm64 \
    libpulse-dev:arm64 \
    libusb-1.0-0-dev:arm64 \
    libgtk2.0-dev:arm64 \
    libopencv-dev:arm64 \
    libassimp-dev:arm64 \
    librtaudio-dev:arm64 \
    gdb:arm64 \
    libglfw3-dev:arm64 \
    libfftw3-dev:arm64 \
    liburiparser-dev:arm64 \
    libpugixml-dev:arm64 \
    libgconf-2-4:arm64 \
    libgtk2.0-0:arm64 \
    libpoco-dev:arm64 \
    libxcursor-dev:arm64 \
    libxi-dev:arm64 \
    libxinerama-dev:arm64 \
    libgstreamer1.0-dev:arm64 \
    libgstreamer-plugins-base1.0-dev:arm64 \
    gstreamer1.0-libav:arm64 \
    gstreamer1.0-pulseaudio:arm64 \
    gstreamer1.0-x:arm64 \
    gstreamer1.0-plugins-bad:arm64 \
    gstreamer1.0-alsa:arm64 \
    gstreamer1.0-plugins-base:arm64 \
    gstreamer1.0-plugins-good:arm64
