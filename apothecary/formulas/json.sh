#!/usr/bin/env bash
#
# json
# JSON for Modern C++ http://nlohmann.github.io/json
# https://github.com/nlohmann/json
#

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")

# define the version
VER=3.11.2

# tools for git use
GIT_URL=https://github.com/nlohmann/json
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
    mkdir json
    cd json    
    downloader "${GIT_URL}/releases/download/v$VER/json.hpp"
	downloader "https://raw.githubusercontent.com/nlohmann/json/master/LICENSE.MIT"
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	echo
	# nothing to do
}

# executed inside the lib src dir
function build() {
    # PATHC should be fixed when moving to 3.0.0
    sed -i -e "s/return \*lhs\.m_value.array < \*rhs\.m_value.array/return (*lhs.m_value.array) < *rhs.m_value.array/g" json.hpp
    #nothing to do, header only lib
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# headers
	mkdir -p $1/include
	cp -v json.hpp $1/include

	# copy license file
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.MIT $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "linux" -o "$TYPE" == "linux64" ] ; then
		rm -f *.hpp *:MIT
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "json" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "json" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
