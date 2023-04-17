#!/usr/bin/env /bash
#
# Brotli is a generic-purpose lossless compression algorithm that compresses data using a combination of a modern variant of the LZ77 algorithm, 
#  Huffman coding and 2nd order context modeling, with a compression ratio comparable to the best currently available general-purpose compression methods.
# It is similar in speed with deflate but offers more dense compression.
# https://github.com/google/brotli

# define the version
VER=1.0.9

# tools for git use
GIT_URL=https://github.com/google/brotli
GIT_TAG=v$VER
VS_VER="16 2019"

FORMULA_TYPES=( "vs" )

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
		mkdir build && cd build
		if [ $VS_VER == 15 ] ; then
			if [ $ARCH == 32 ] ; then
				cmake . -G "Visual Studio $VS_VER Win32"
				cmake --build . --config Release
			elif [ $ARCH == 64 ] ; then
				cmake . -G "Visual Studio $VS_VER Win64"
				cmake --build . --config Release
			elif [ $ARCH == "arm" ]; then
				cmake . -G "Visual Studio $VS_VER ARM"
				cmake --build . --config Release
			fi
		else
			if [ $ARCH == 32 ] ; then
				cmake . -G "Visual Studio $VS_VER" -A Win32
				cmake --build . --config Release
			elif [ $ARCH == 64 ] ; then
				cmake . -G "Visual Studio $VS_VER" -A x64
				cmake --build . --config Release
			elif [ $ARCH == "arm" ]; then
				cmake . -G "Visual Studio $VS_VER" -A ARM
				cmake --build . --config Release
			elif [ $ARCH == "arm64" ] ; then
				cmake . -G "Visual Studio $VS_VER" -A ARM64
				cmake --build . --config Release
			fi
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
		elif [ $ARCH == 64 ] ; then
			PLATFORM="x64"
		elif [ $ARCH == "arm64" ] ; then
			PLATFORM="ARM64"
		elif [ $ARCH == "arm" ]; then
			PLATFORM="ARM"
		fi
		# mkdir -p $1/../cairo/lib/$TYPE/$PLATFORM/
		# cp -v Release/zlibstatic.lib $1/../cairo/lib/$TYPE/$PLATFORM/zlib.lib
	else
		make install
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		
	else
		make uninstall
		make clean
	fi
}
