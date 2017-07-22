#!/usr/bin/env bash
#
# libusb for ofxKinect needed for 
# Visual Studio and OS X

FORMULA_TYPES=( "vs" "osx" )

# define the version
VER=v1.0.21

# tools for git use
GIT_URL=https://github.com/libusb/libusb
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	git clone ${GIT_URL}
	
	if [ "$TYPE" == "vs" ] ; then
		cd libusb
		git fetch https://github.com/cuisinart/libusb/ 
		git cherry-pick b680238def7b61a9a2b7e6dd4539ca0e631ce068

		#this doesn't work - the above should be the same 
		#git remote add jblake https://github.com/JoshBlake/libusbx.git
		#git fetch jblake
		#git cherry-pick c5b0af4 1c74211
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
}

# executed inside the lib src dir
function build() {


	if [ "$TYPE" == "vs" ] ; then
	
		cd msvc
		
		if [ $ARCH == 32 ] ; then
			MSBuild.exe libusb_2015.sln //t:Build //p:Configuration=Release
		elif [ $ARCH == 64 ] ; then
			MSBuild.exe libusb_2015.sln //t:Build //p:Configuration=Release //p:Platform=x64
		fi		

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -Rv libusb/libusb.h $1/include

	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v Win32/Release/lib/libusb-1.0.lib $1/lib/$TYPE/Win32/libusb-1.0.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v x64/Release/lib/libusb-1.0.lib $1/lib/$TYPE/x64/libusb-1.0.lib
		fi
		
	fi

	echoWarning "TODO: License Copy"
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		cd msvc
		MSBuild.exe libusb_2015.sln //t:Clean
	fi
}
