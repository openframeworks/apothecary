#!/usr/bin/env bash
#
# fmod
# https://www.fmod.com
#
# This is not a build script, as fmod is linked as a dynamic library.
# fmod is downloaded as a binary from the fmod.com website and copied
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
		mkdir fmod
		return;
	fi
	if [ "$TYPE" == "vs" ]; then
		PKG=fmod_${TYPE}${ARCH}.tar.bz2
	else
		PKG=fmod_${TYPE}.tar.bz2
	fi
	wget -nv http://ci.openframeworks.cc/libs/fmod/$PKG
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
		install_name_tool -id "@rpath/libfmod.dylib" libfmod.dylib
		cd ../
	fi


}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	cp -r ../fmod $1/
}

# executed inside the lib src dir
function clean() {
	: # noop
}
