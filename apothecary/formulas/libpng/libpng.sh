#!/usr/bin/env bash
#
# the official PNG reference library
# http://libpng.org/pub/png/libpng.html

# define the version
MAJOR_VER=16
VER=1.6.37

# tools for git use
GIT_URL=http://git.code.sf.net/p/libpng/code
GIT_TAG=v$VER
URL=https://prdownloads.sourceforge.net/libpng
SHA=
WINDOWS_URL=https://prdownloads.sourceforge.net/libpng/lpng1637.zip

FORMULA_TYPES=( "osx" "vs" )

FORMULA_DEPENDS=( "zlib" )


# download the source code and unpack it into LIB_NAME
function download() {
	if [ "$TYPE" == "vs" ] ; then
		wget -nv --no-check-certificate ${WINDOWS_URL}?download -O libpng-$VER.zip
		unzip libpng-$VER.tar.zip
		mv lpng1637 libpng
		rm libpng-$VER.zip
	else 
		wget -nv --no-check-certificate ${URL}/libpng-$VER.tar.gz?download -O libpng-$VER.tar.gz
		tar -xf libpng-$VER.tar.gz
		mv libpng-$VER libpng
		rm libpng-$VER.tar.gz
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {

	

	# generate the configure script if it's not there
	if [ ! -f configure ] ; then
		./autogen.sh
	fi
	if [ "$TYPE" == "vs" ] ; then

		apothecaryDepend prepare zlib
		apothecaryDepend build zlib
		apothecaryDepend copy zlib

		#need to download this for the vs solution to build
		if [ ! -e ../zlib ] ; then
			echoError "libpng needs zlib, please update that formula first"
		fi
		#CURRENTPATH=`pwd`
		cp -vr $FORMULA_DIR/vs2015 projects/
		# ls ../zlib
		# ls ../zlib/Release
		# cp ../zlib/Release/zlib.lib ../zlib/zlib.lib
	fi


	
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "osx" ] ; then
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

        ROOT=${PWD}/..
		export INCLUDE_ZLIB="-I$ROOT/zlib/build/"
		export INCLUDE_ZLIB_LIBS="-L$ROOT/zlib/build/ -lz"
    	    
		# these flags are used to create a fat arm/64 binary with libc++
		# see https://gist.github.com/tgfrerer/8e2d973ed0cfdd514de6
		local FAT_LDFLAGS="-arch arm64 -arch x86_64 -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot ${SDK_PATH}"

		./configure LDFLAGS="${FAT_LDFLAGS} -flto ${INCLUDE_ZLIB_LIBS}" \
				CFLAGS="-O3 ${FAT_LDFLAGS} ${INCLUDE_ZLIB}" \
				--prefix=$BUILD_ROOT_DIR \
				--disable-dependency-tracking \
                --disable-arm-neon \
                --disable-shared
		make clean
		make
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP

		mkdir build
		cd build

		if [ $ARCH == 32 ] ; then
			cmake .. -G "Visual Studio $VS_VER Win32"
			cmake --build . --config Release
		elif [ $ARCH == 64 ] ; then
			cmake .. -G "Visual Studio $VS_VER Win64"
			cmake --build . --config Release
		elif [ $ARCH == "ARM" ] ; then
			cmake .. -G "Visual Studio $VS_VER ARM"
			cmake --build . --config Release
		fi

		cd ..
		
		# PNG_BUILD_ZLIB
		# ZLIB_ROOT
		# cd projects/vstudio

		# vs-upgrade vstudio.sln

		# if [ $ARCH == 32 ] ; then
		# 	vs-build vstudio.sln Build "Release Library|x86"
		# elif [ $ARCH == 64 ] ; then
		# 	vs-build vstudio.sln Build "Release Library|x64"
		# fi
		# cd ../../
	fi



}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "vs" ] ; then
		if [ "$ARCH" == 32 ]; then
			mkdir -p $1/../cairo/lib/vs/Win32/
			cp ../libpng/projects/vs2015/Win32_LIB_Release/libpng.lib $1/../cairo/lib/vs/Win32/
		else
			mkdir -p $1/../cairo/lib/vs/x64/
			cp ../libpng/projects/vs2015/x64/LIB\ Release/libpng.lib $1/../cairo/lib/vs/x64/
		fi
	else
		echo "no copy osx"
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			echo "to do clean vs build"
		fi
	else
		make uninstall
		make clean
	fi
}
