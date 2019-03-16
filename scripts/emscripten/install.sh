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

# docker exec -it emscripten echo $PATH
# docker exec -it emscripten mkdir -p /home/travis/bin
# docker exec -it emscripten sh -c "echo '#!/usr/bin/env bash' > /home/travis/bin/emcmake"
# docker exec -it emscripten sh -c "echo '$@' >> /home/travis/bin/emcmake"
# docker exec -it emscripten sh -c "chmod 755 /home/travis/bin/emcmake;"

docker exec -it emscripten apt update
docker exec -it emscripten apt install -y coreutils libboost-tools-dev rsync gperf