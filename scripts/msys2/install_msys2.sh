#!/usr/bin/env bash

# https://www.msys2.org
# Update package database 
pacman -Syuu --noconfirm
pacman -S --noconfirm base-devel unzip dos2unix git
pacboy -S --noconfirm gcc cmake gperf libxml2 python3 zlib

# Additional
pacboy -S --noconfirm mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja
pacboy -S --noconfirm mingw-w64-x86_64-ffmpeg mingw-w64-x86_64-openssl mingw-w64-x86_64-wxWidgets
pacboy -S --noconfirm mingw-w64-x86_64-boost mingw-w64-x86_64-curl mingw-w64-x86_64-git

# Clean
pacman -Scc --noconfirm
echo "MSYS2 setup is complete. Please restart shell."

