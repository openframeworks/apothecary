#!/usr/bin/env bash
#
# utf8cpp
# 
#
FORMULA_TYPES=( "osx" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "vs" "ios" "tvos" "android" "emscripten" )

# define the version
VER=3.2.1
VER_=3_2_1

# tools for git use
GIT_URL=https://github.com/nemtrif/utfcpp
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv ${GIT_URL}/archive/refs/tags/v${VER}.zip 
	unzip v${VER}.zip 
	mv utfcpp-${VER} utf8
    rm v${VER}.zip
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	echo
	# nothing to do
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
	cp -vr source/* $1/include
}

# executed inside the lib src dir
function clean() {
    echo
    #nothing to do header ony lib
}
