#!/bin/bash

VERSION=3.1.64

if [ -z "${EMSDK+x}" ]; then
	echo "Unix Emscripten SDK not yet found"
	echo "Emscripten Download SRC"
	cd ../../
	git clone https://github.com/emscripten-core/emsdk.git
	cd emsdk
	git pull

	echo "if any issues with python - make sure to add python paths to bash environment Variables:"
  python -m pip install --upgrade pip setuptools virtualenv
  ./emsdk install latest
  ./emsdk activate latest --permanent
else
	echo "Emscripten SDK found at $EMSDK"
	cd ${EMSDK}
	./emsdk install latest
  ./emsdk activate latest --permanent
  source "$EMSDK/emsdk_env.sh"
fi
