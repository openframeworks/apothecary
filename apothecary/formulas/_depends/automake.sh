#!/usr/bin/env /bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

# define the version
VER=1.16.4

# tools for git use
GIT_URL=https://ftp.gnu.org/gnu/automake/automake
GIT_TAG=v$VER

FORMULA_TYPES=( "linuxarmv6l" )

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv --no-check-certificate ${GIT_URL}-$VER.tar.gz -O automake-$VER.tar.gz
	tar -xf automake-$VER.tar.gz
	mv automake-$VER zlib
	rm automake-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: #noop
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "linuxarmv6l" ] ; then
		./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.3
		make
		make install
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "linuxarmv6l" ] ; then
		
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "linuxarmv6l" ] ; then
		
		make uninstall
		make clean
	fi
}
