#!/bin/bash

VERSION="latest"

# Check if EMSDK is set and valid
if [[ -z "$EMSDK" || ! -d "$EMSDK/upstream/emscripten" ]]; then
    echo "🔹 Emscripten SDK not found or invalid. Installing the latest version..."
    cd $HOME
    if [ ! -d "emsdk" ]; then
        git clone https://github.com/emscripten-core/emsdk.git
    fi

    cd emsdk
    git pull

    echo "Installing/updating Python dependencies..."
    python3 -m pip install --upgrade pip setuptools virtualenv

    ./emsdk install "$VERSION"
    ./emsdk activate "$VERSION" --permanent

    echo "EMSDK=$HOME/emsdk" >> $HOME/.bashrc
    echo 'export PATH="$HOME/emsdk:$HOME/emsdk/upstream/emscripten:$PATH"' >> $HOME/.bashrc
    source $HOME/.bashrc
else
    echo "Emscripten SDK found at $EMSDK. Updating to the latest version..."
    cd "$EMSDK"
    ./emsdk install "$VERSION"
    ./emsdk activate "$VERSION" --permanent
fi

source "$HOME/emsdk/emsdk_env.sh"
echo "Emscripten version: $(emcc --version)"
