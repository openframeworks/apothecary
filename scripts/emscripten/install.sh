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
git clone --depth 1 --single-branch --branch v1.38.4-trusty https://github.com/urho3d/emscripten-sdk
cd emscripten-sdk
./emsdk activate incoming
