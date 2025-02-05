#!/usr/bin/env bash

EMSDK_VERSION=${EMSDK_VERSION:-latest}

if [ ! -d "$HOME/emsdk/upstream/emscripten" ]; then
    echo "===Emscripten SDK not found. Installing...==="
    if [ ! -d "$HOME/emsdk" ]; then
        git clone https://github.com/emscripten-core/emsdk.git $HOME/emsdk
    fi
    cd $HOME/emsdk
    ./emsdk install "$EMSDK_VERSION"
    ./emsdk activate "$EMSDK_VERSION"
    echo "EMSDK_PATH=$HOME/emsdk" >> $GITHUB_ENV
    echo "EMSCRIPTEN=$HOME/emsdk/upstream/emscripten" >> $GITHUB_ENV
    echo 'export PATH="$HOME/emsdk:$HOME/emsdk/upstream/emscripten:$PATH"' >> $HOME/.bashrc
    source $HOME/emsdk/emsdk_env.sh
else
    echo "Emscripten SDK already installed at $HOME/emsdk"
fi
if [ -d "$HOME/emsdk/upstream/emscripten" ]; then
    source "$HOME/emsdk/emsdk_env.sh"
    echo "Emscripten version: $(emcc --version)"
else
    echo "Error: Emscripten SDK directory not found at $HOME/emsdk/upstream/emscripten"
    exit 1
fi
