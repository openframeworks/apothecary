#!/usr/bin/env bash
#
# glm
# OpenGL Mathematics
# https://github.com/g-truc/glm
#

FORMULA_TYPES=( "osx" "msys2" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")
FORMULA_DEPENDS=(  )

# tools for git use
GIT_URL=https://github.com/g-truc/glm
#GIT_TAG=1.0.0.0
GIT_TAG=master
VER=1.0.1

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
    # we should just build this
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# headers
	mkdir -p $1/include
	cp -rv glm $1/include
	
	. "$SECURE_SCRIPT"
	secure $1/include/glm/glm.hpp glm.pkl

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

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "glm" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/include" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
