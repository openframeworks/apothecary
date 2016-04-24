#! /bin/bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

# define the version
VER=1.2.8

# tools for git use
GIT_URL=https://github.com/madler/zlib.git
GIT_TAG=v$VER

# download the source code and unpack it into LIB_NAME
function download() {
	# Skip dowloading for "MSYS2"
	if [ "$TYPE" == "msys2" ] ; then
		mkdir zlib #apothecary will complain about failed download if it doesn't find this directory
		return
	fi
	
	curl -LO http://zlib.net/zlib-$VER.tar.gz
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
	if [ "$TYPE" == "osx" ] ; then
		echo "build not needed for $TYPE"
	elif [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			cmake -G "Visual Studio $VS_VER"
			vs-build "zlib.sln"
		elif [ $ARCH == 64 ] ; then
			cmake -G "Visual Studio $VS_VER Win64"
			vs-build "zlib.sln" Build "Release|x64"
		fi
	elif [ "$TYPE" == "msys2" ] ; then
		#Install zlib with pacman if not present
		local MSYS2_ARCH=i686
		if [ $ARCH == 64 ] ; then 
			MSYS2_ARCH=x86_64
		fi
		pkg_name=mingw-w64-${MSYS2_ARCH}-zlib
		installed_pkg=`pacman -Q $pkg_name 2>/dev/null`
		if [ -n "$installed_pkg" ] ; then
			echoVerbose "package already installed : $installed_pkg"
		else
			echoVerbose "installing package : $pkg_name"
			pacman --noconfirm -Sy $pkg_name
		fi
		return
	else
		./configure --static \
					--prefix=$BUILD_ROOT_DIR 
		make clean; 
		make
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "osx" -o "$TYPE" == "msys2" ] ; then
		return
	elif [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			cp -v Release/zlib.dll $1/../../export/$TYPE/Win32/Zlib.dll
		elif [ $ARCH == 64 ] ; then
			cp -v Release/zlib.dll $1/../../export/$TYPE/x64/Zlib.dll
		fi
		
	else
		make install
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "osx" -o "$TYPE" == "msys2" ] ; then
		return
	fi
	if [ "$TYPE" == "vs" ] ; then
		vs-clean "zlib.sln"
	else
		make uninstall
		make clean
	fi
}
