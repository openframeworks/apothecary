#!/usr/bin/env bash
#
# json
# JSON for Modern C++ http://nlohmann.github.io/json
# https://github.com/nlohmann/json
#

FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "tvos" "android" "emscripten")

# define the version
VER=3.11.2

# tools for git use
GIT_URL=
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
    mkdir json
    cd json
	wget -nv https://github.com/nlohmann/json/releases/download/v$VER/json.hpp
	wget -nv https://raw.githubusercontent.com/nlohmann/json/master/LICENSE.MIT
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
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE.MIT $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "linux" -o "$TYPE" == "linux64" ] ; then
		rm -f *.hpp *:MIT
	fi
}
