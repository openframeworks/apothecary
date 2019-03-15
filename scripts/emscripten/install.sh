#!/bin/bash

#set -e
#set -o pipefail

# trap any script errors and exit
# trap "trapError" ERR

# SUDO=

# trapError() {
# 	echo
# 	echo " ^ Received error ^"
# 	exit 1
# }

# cd $TRAVIS_BUILD_DIR

# cp scripts/emscripten/.emscripten ~/
# sed -i "s|%HOME%|${HOME}|g" ~/.emscripten
# cd ~/
# git clone --depth 1 --single-branch --branch master https://github.com/urho3d/emscripten-sdk
# cd emscripten-sdk
# ./emsdk activate --build=Release sdk-master-64bit

docker exec -it emscripten sudo touch /usr/bin/emcmake;
docker exec -it emscripten sudo chmod 755 /usr/bin/emcmake;