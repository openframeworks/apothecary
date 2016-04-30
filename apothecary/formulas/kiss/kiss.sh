#! /bin/bash
#
# KissFFT
# "Keep It Simple, Stupid" Fast Fourier Transform
# http://sourceforge.net/projects/kissfft/
#
# has a Makefile
FORMULA_TYPES=( "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "msys2")

# define the version
VER=130
VER_UNDERSCORE=1_3_0

# tools for git use
GIT_URL=
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
	wget http://downloads.sourceforge.net/project/kissfft/kissfft/v$VER_UNDERSCORE/kiss_fft$VER.tar.gz
	tar -xf kiss_fft$VER.tar.gz
	mv kiss_fft$VER kiss
	rm kiss_fft$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	cp -Rv $FORMULA_DIR/Makefile .
}

# executed inside the lib src dir
function build() {
    if [ $CROSSCOMPILING -eq 1 ]; then
        source ../../${TYPE}_configure.sh
    fi
	
	if [ "$TYPE" == "msys2" ] ; then
		if [ $ARCH == 64 ] ; then 
			make  -j${PARALLEL_MAKE} TARGET_DIR=$TYPE/x64
		else
			make  -j${PARALLEL_MAKE} TARGET_DIR=$TYPE/Win32
		fi
		return
	fi
    make  -j${PARALLEL_MAKE} TARGET_DIR=$TYPE
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# headers
	mkdir -p $1/include
	cp -v kiss_fft.h $1/include
	cp -v tools/kiss_fftr.h $1/include

	local LIB_DIR=lib/$TYPE
	mkdir -p $1/$LIB_DIR
	if [ "$TYPE" == "msys2" ] ; then
		if [ $ARCH == 64 ] ; then
			LIB_DIR=$LIB_DIR/x64		
		else
			LIB_DIR=$LIB_DIR/Win32
		fi
		mkdir -p $1/$LIB_DIR
	fi
	
	cp -v $LIB_DIR/libkiss.a $1/$LIB_DIR/libkiss.a
	
	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
	local LIB_DIR=lib/$TYPE
	if [ "$TYPE" == "msys2" ] ; then
		rm -f *.o
		rm -rf lib/
		return
	fi
	if [ "$TYPE" == "linux" -o "$TYPE" == "linux64" -o "$TYPE" == "msys2" ] ; then
		make clean
		rm -f *.a
	fi
}
