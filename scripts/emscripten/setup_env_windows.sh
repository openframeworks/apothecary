#!/bin/bash

VERSION=3.1.35

if [ -z "${EMSDK+x}" ]; then
	echo "Windows Emscripten SDK not yet found"
	echo "Emscripten Download SRC"
	cd ../../
	git clone https://github.com/emscripten-core/emsdk.git
	cd emsdk
	git pull

	echo "if any issues with python - make sure to add python paths to Windows environment Variables - System PATH: as well as user PATH:"
  python -m pip install --upgrade pip setuptools virtualenv
  ./emsdk.bat install latest
  ./emsdk.bat activate latest --permanent
  ./emsdk_env.bat
  ./emsdk.bat install ${VERSION}  
	
else
  echo "Emscripten SDK found at $EMSDK"
  "$EMSDK/emsdk_env.bat"  
fi
