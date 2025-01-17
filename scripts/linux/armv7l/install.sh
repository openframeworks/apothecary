#!/bin/bash
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"

sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils
sudo aptitude install -y gperf
sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev
sudo apt-get install -y ccache

sudo apt-get install -y ccache
sudo apt-get install gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf
sudo apt-get install \
    libboost-iostreams1.83.0:armhf \
    libcwidget4:armhf \
    libsigc++-2.0-0v5:armhf \
    libxapian30:armhf \
    libasound2-plugins:armhf \
    libosmesa6:armhf \
    libpcsclite1:armhf \
    libspeexdsp1:armhf \
    libwine:armhf \
    libxkbregistry0:armhf \
    libz-mingw-w64:armhf \
    wine:armhf \
    wget2:armhf \
    make:armhf \
    libjack-jackd2-0:armhf \
    libjack-jackd2-dev:armhf \
    freeglut3-dev:armhf \
    libasound2-dev:armhf \
    libxmu-dev:armhf \
    libxxf86vm-dev:armhf \
    g++:armhf \
    libgl1-mesa-dev:armhf \
    libglu1-mesa-dev:armhf \
    libraw1394-dev:armhf \
    libudev-dev:armhf \
    libdrm-dev:armhf \
    libglew-dev:armhf \
    libopenal-dev:armhf \
    libsndfile1-dev:armhf \
    libfreeimage-dev:armhf \
    libcairo2-dev:armhf \
    libfreetype6-dev:armhf \
    libpulse-dev:armhf \
    libusb-1.0-0-dev:armhf \
    libgtk2.0-dev:armhf \
    libopencv-dev:armhf \
    libassimp-dev:armhf \
    librtaudio-dev:armhf \
    gdb:armhf \
    libglfw3-dev:armhf \
    libfftw3-dev:armhf \
    liburiparser-dev:armhf \
    libpugixml-dev:armhf \
    libgconf-2-4:armhf \
    libgtk2.0-0:armhf \
    libpoco-dev:armhf \
    libxcursor-dev:armhf \
    libxi-dev:armhf \
    libxinerama-dev:armhf \
    libgstreamer1.0-dev:armhf \
    libgstreamer-plugins-base1.0-dev:armhf \
    gstreamer1.0-libav:armhf \
    gstreamer1.0-pulseaudio:armhf \
    gstreamer1.0-x:armhf \
    gstreamer1.0-plugins-bad:armhf \
    gstreamer1.0-alsa:armhf \
    gstreamer1.0-plugins-base:armhf \
    gstreamer1.0-plugins-good:armhf

