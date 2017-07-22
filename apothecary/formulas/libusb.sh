#!/usr/bin/env bash
#
# libusb for ofxKinect needed for 
# Visual Studio and OS X

FORMULA_TYPES=( "vs" "osx" )

# define the version
# for vs latest release is good
VER=v1.0.21
GIT_URL_VS=https://github.com/libusb/libusb
GIT_TAG_VS=$VER

# for osx 1.0.21 breaks libfreenect so this branch has 1.0.20 with changes to the XCode project to make it build static and not dynamic
GIT_URL_OSX=https://github.com/ofTheo/libusb
GIT_BRANCH_OSX=osx-kinect

# download the source code and unpack it into LIB_NAME
function download() {

	if [ "$TYPE" == "vs" ] ; then
        echo "Running: git clone --branch ${GIT_TAG_VS} ${GIT_URL_VS}"
        git clone --branch ${GIT_TAG_VS} ${GIT_URL_VS}

		cd libusb
		git fetch https://github.com/cuisinart/libusb/ 
		git cherry-pick b680238def7b61a9a2b7e6dd4539ca0e631ce068

		#this doesn't work - the above should be the same 
		#git remote add jblake https://github.com/JoshBlake/libusbx.git
		#git fetch jblake
		#git cherry-pick c5b0af4 1c74211
	fi

	if [ "$TYPE" == "osx" ] ; then
        echo "Running: git clone --branch ${GIT_BRANCH_OSX} ${GIT_URL_OSX}"
    	git clone --branch ${GIT_BRANCH_OSX} ${GIT_URL_OSX}
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

    if [ "$TYPE" == "osx" ] ; then
        cd Xcode
    	xcodebuild -configuration Release -target libusb -project libusb.xcodeproj/
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

    if [ "$TYPE" == "osx" ] ; then
        mkdir -p $1/lib/$TYPE
        cp -v Xcode/build/Release/libusb-1.0.0.a $1/lib/$TYPE/usb-1.0.0.lib
	fi

	echoWarning "TODO: License Copy"
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		cd msvc
		MSBuild.exe libusb_2015.sln //t:Clean
	fi

    if [ "$TYPE" == "osx" ] ; then
        cd Xcode
    	xcodebuild -configuration Release -target libusb -project libusb.xcodeproj/ clean
	fi
}
