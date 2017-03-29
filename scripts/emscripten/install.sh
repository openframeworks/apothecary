#!/bin/bash
#set -e
#set -o pipefail
# trap any script errors and exit
trap "trapError" ERR

SUDO=

trapError() {
	echo
	echo " ^ Received error ^"
	exit 1
}

cd ~/
wget https://cmake.org/files/v3.7/cmake-3.7.2.tar.gz
tar -xzf cmake-3.7.2.tar.gz
cd cmake-3.7.2/
./configure
make
sudo make install
sudo update-alternatives --install /usr/bin/cmake cmake /usr/local/bin/cmake 1 --force
cmake --version

cd $TRAVIS_BUILD_DIR

cp scripts/emscripten/.emscripten ~/
sed -i "s|%HOME%|${HOME}|g" ~/.emscripten
cd ~/
git clone https://github.com/urho3d/emscripten-sdk
cd emscripten-sdk
./emsdk activate latest
