#! /bin/bash
#
# utf8cpp
# http://utfcpp.sourceforge.net/
#

# define the version
VER=2.3.4
VER_=2_3_4

# tools for git use
GIT_URL=
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
	curl -LO http://downloads.sourceforge.net/project/utfcpp/utf8cpp_2x/Release%20${VER}/utf8_v${VER_}.zip
	mkdir utf8
	cd utf8
	unzip ../utf8_v${VER_}.zip
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
