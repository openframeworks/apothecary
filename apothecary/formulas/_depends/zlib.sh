#!/usr/bin/env /bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

# define the version
VER=1.2.12

# tools for git use
GIT_URL=https://github.com/madler/zlib/archive/refs/tags
GIT_TAG=v$VER

FORMULA_TYPES=( "vs" , "osx")

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
		if [ $VS_VER == 15 ] ; then
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
		else
			if [ $ARCH == 32 ] ; then
				cmake . -G "Visual Studio $VS_VER" -A Win32
				cmake --build . --config Release
			elif [ $ARCH == 64 ] ; then
				cmake . -G "Visual Studio $VS_VER" -A x64
				cmake --build . --config Release
			elif [ $ARCH == "ARM" ] ; then
				cmake . -G "Visual Studio $VS_VER" -A ARM
				cmake --build . --config Release 
			elif [ $ARCH == "ARM64" ] ; then
				cmake . -G "Visual Studio $VS_VER" -A ARM64
				cmake --build . --config Release 
			fi
		fi
	elif [ "$TYPE" == "osx" ] ; then
		mkdir -p build
		cd build

		local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        SYSROOT="-isysroot ${SDK_PATH}"
        export SDK=macosx
        export DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER}
        export ARCHS="-arch arm64 -arch x86_64"

		export CFLAGS="-O2 ${ARCHS} -fomit-frame-pointer -fno-stack-protector -pipe -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot ${SDK_PATH}"

		cmake .. \
		    -G "Unix Makefiles" \
		    -D CMAKE_VERBOSE_MAKEFILE=ON \
		    -D BUILD_SHARED_LIBS=ON \
		# cmake .. -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -G "Unix Makefiles" 
		make
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "osx" ] ; then
		echo "no install"
	elif [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		elif [ $ARCH == 64 ] ; then
			PLATFORM="x64"
		elif [ $ARCH == "ARM64" ] ; then
			PLATFORM="ARM64"
		elif [ $ARCH == "ARM" ] ; then
			PLATFORM="ARM"
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
