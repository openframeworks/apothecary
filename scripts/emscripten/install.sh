#!/bin/bash

docker exec -it emscripten apt update
docker exec -it emscripten apt install -y coreutils libboost-tools-dev
docker exec -it emscripten apt install -y rsync
docker exec -it emscripten apt install -y gperf
docker exec -it emscripten apt install -y ccache
docker exec -it emscripten ln -s /usr/bin/ccache /usr/lib/ccache/emcc
docker exec -it emscripten sh -c 'echo $PATH'