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

cd $TRAVIS_BUILD_DIR

cp scripts/emscripten/.emscripten ~/
sed -i "s|%HOME%|${HOME}|g" ~/.emscripten
cd ~/
git clone --depth 1 --single-branch --branch master https://github.com/urho3d/emscripten-sdk
cd emscripten-sdk
# ./emsdk activate --build=Release sdk-master-64bit
./emsdk update
./emsdk install sdk-1.38.28-64bit
./emsdk activate sdk-1.38.28-64bit

# cd ~/
# git clone --depth=1 --single-branch --branch master https://github.com/emscripten-core/emsdk.git emscripten-sdk
# cd emscripten-sdk
# ./emsdk install sdk-1.38.28-64bit
# ./emsdk activate sdk-1.38.28-64bit
