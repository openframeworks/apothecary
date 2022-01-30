#!/usr/bin/env /bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

# define the version
VER=1.2.11

# tools for git use
GIT_URL=https://github.com/madler/zlib/releases/tag
GIT_TAG=v$VER
VS_VER="16 2019"

FORMULA_TYPES=( "vs")

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv --no-check-certificate ${GIT_URL}/v$VER.tar.gz -O zlib-$VER.tar.gz
	tar -xf zlib-$VER.tar.gz
	mv zlib-$VER zlib
	rm zlib-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: #noop
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		if [ $ARCH == 32 ] ; then
			cmake . -G "Visual Studio $VS_VER Win32"
			cmake --build . --config Release
		elif [ $ARCH == 64 ] ; then
			cmake . -G "Visual Studio $VS_VER Win64"
			cmake --build . --config Release
		elif [ $ARCH == "ARM" ] ; then
			cmake . -G "Visual Studio $VS_VER ARM"
			cmake --build . --config Release
		fi
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "osx" ] ; then
		return
	elif [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		else
			PLATFORM="x64"
		fi
		mkdir -p $1/../cairo/lib/$TYPE/$PLATFORM/
		cp -v Release/zlibstatic.lib $1/../cairo/lib/$TYPE/$PLATFORM/zlib.lib
	else
		make install
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		vs-clean "${VS_VER}/zlib.sln"
	else
		make uninstall
		make clean
	fi
}
