#!/usr/bin/env bash
#
# glm
# OpenGL Mathematics
# https://github.com/g-truc/glm
#

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")

# tools for git use
GIT_URL=https://github.com/g-truc/glm
#GIT_TAG=0.9.9.8
GIT_TAG=master

# download the source code and unpack it into LIB_NAME
function download() {
	git clone --branch $GIT_TAG --depth=1 $GIT_URL 
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	echo
}

# executed inside the lib src dir
function build() {
    echo
    #nothing to do, header only lib
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# headers
	mkdir -p $1/include
	cp -rv glm $1/include

	# copy license file
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v copying.txt $1/license/license.txt
}

# executed inside the lib src dir
function clean() {
    echo
	# nothing to do
}
