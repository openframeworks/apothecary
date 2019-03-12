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

# cp scripts/emscripten/.emscripten ~/
# sed -i "s|%HOME%|${HOME}|g" ~/.emscripten
# cd ~/
# git clone https://github.com/urho3d/emscripten-sdk
# cd emscripten-sdk
# ./emsdk activate latest

git clone --depth=1 https://github.com/emscripten-core/emsdk.git emscripten-sdk
cd emscripten-sdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
