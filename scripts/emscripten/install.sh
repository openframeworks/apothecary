#!/bin/bash

if [[ -n "$DOCKER" ]]; then
    echo "Running inside Docker: Installing dependencies in the emscripten container..."
    docker exec -i emscripten apt update && \
    docker exec -i emscripten apt install -y \
      coreutils libboost-tools-dev rsync gperf ccache build-essential \
      autoconf automake pkgconf cmake libtool multistrap unzip dos2unix
    docker exec -i emscripten sh -c "echo \$PATH"
else
    echo "Running natively: Installing dependencies on the host system..."
    sudo apt-get update && \
    sudo apt-get install -y \
      coreutils libboost-tools-dev rsync gperf ccache build-essential \
      autoconf automake pkgconf cmake libtool multistrap unzip dos2unix
fi
