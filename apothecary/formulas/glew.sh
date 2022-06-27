#!/usr/bin/env bash
#
# GLEW
# OpenGL Extensions Wrangler
# http://glew.sourceforge.net/
#
# uses a Makefile build system,
# use "make glew.lib" to build only the lib without demos/tests
# the OPT flag is used for CFLAGS (& LDFLAGS I think?)

FORMULA_TYPES=( "osx" "vs" )

# define the version
VER=1.11.0

# tools for git use
GIT_URL=https://github.com/nigels-com/glew.git
GIT_TAG=glew-$VER

# download the source code and unpack it into LIB_NAME
function download() {
	#echo ${VS_VER}0
	curl -LO http://downloads.sourceforge.net/project/glew/glew/$VER/glew-$VER.tgz
	tar -xf glew-$VER.tgz
	mv glew-$VER glew
	rm glew-$VER.tgz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "osx" ] ; then

		# GLEW will not allow one to simply supply OPT="-arch arm64 -arch x86_64"
		# so we build them separately.

		# arm64
		make clean; make -j${PARALLEL_MAKE} glew.lib OPT="-arch arm64  -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		mv lib/libGLEW.a libGLEW-arm64.a

		# 64 bit
		make clean; make -j${PARALLEL_MAKE} glew.lib OPT="-arch x86_64  -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		mv lib/libGLEW.a libGLEW-x86_64.a

		# link into fat universal lib
		lipo -c libGLEW-arm64.a libGLEW-x86_64.a -o libGLEW.a

	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd build/vc12 #this upgrades without issue to vs2015
		#vs-clean "glew.sln"
		vs-upgrade "glew.sln"
		if [ "$ARCH" == "32" ]; then
			vs-build "glew_static.vcxproj" Build "Release|Win32"
		else
			vs-build "glew_static.vcxproj" Build "Release|x64"
		fi
		cd ../../
	elif [ "$TYPE" == "msys2" ] ; then
		make clean
		make
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	rm -rf $1/include
	mkdir -p $1/include
	cp -Rv include/* $1/include

	rm -rf $1/lib/$TYPE/*

	# libs
	if [ "$TYPE" == "osx" ] ; then
		mkdir -p $1/lib/$TYPE
		cp -v libGLEW.a $1/lib/$TYPE/glew.a

	elif [ "$TYPE" == "vs" ] ; then
		if [ "$ARCH" == "32" ]; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v lib/Release/Win32/glew32s.lib $1/lib/$TYPE/Win32
		else
			mkdir -p $1/lib/$TYPE/x64
			cp -v lib/Release/x64/glew32s.lib $1/lib/$TYPE/x64
		fi
	elif [ "$TYPE" == "msys2" ] ; then
		# TODO: add cb formula
		mkdir -p $1/lib/$TYPE
		cp -v lib/libglew32.a $1/lib/$TYPE
	fi

	# copy license files
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		cd build/vc12
		vs-clean "glew.sln"
		cd ../../
	else
		make clean
		rm -f *.a *.lib
	fi
}
