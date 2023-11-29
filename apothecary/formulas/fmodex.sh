#!/usr/bin/env bash
#
# FmodEX
# http://www.portaudio.com/
#
# This is not a build script, as fmodex is linked as a dynamic library.
# FmodEX is downloaded as a binary from the fmod.org website and copied
# into the openFrameworks library directory.


FORMULA_TYPES=( "msys2" "osx" "vs" "linux" "linux64" )

# define the version
VER=44459

# tools for git use
GIT_URL=
GIT_TAG=

# download the source code and unpack it into LIB_NAME
function download() {
	#Nothing to do for mingw64
	if [ "$TYPE" == "msys2" ] && [ "$ARCH" == "64" ]; then
		mkdir fmodex
		return;
	fi
	if [ "$TYPE" == "vs" ]; then
		PKG=fmodex_${TYPE}${ARCH}.tar.bz2
	else
		PKG=fmodex_${TYPE}.tar.bz2
	fi
	wget -nv http://openframeworks.cc/ci/fmodex/$PKG
	tar xjf $PKG
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
	# mount install
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "osx" ]; then
		cd lib/osx
		install_name_tool -id "@executable_path/libfmodex.dylib" libfmodex.dylib
		cd ../
	fi


}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	cp -r ../fmodex $1/
}

# executed inside the lib src dir
function clean() {
	: # noop
}
