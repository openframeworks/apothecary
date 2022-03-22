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
		wget -nv --no-check-certificate ${WINDOWS_URL}?download -O lpng1637.zip
		unzip lpng1637.zip
		mv lpng1637 libpng
		rm lpng1637.zip
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

	apothecaryDepend download zlib
	apothecaryDepend prepare zlib
	apothecaryDepend build zlib
	apothecaryDepend copy zlib

	if [ "$TYPE" == "vs" ] ; then

		

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

		mkdir -p build
    	    
    	export OUTPUT_BUILD_DIR=$(realpath ${PWD}/build)
		# these flags are used to create a fat arm/64 binary with libc++
		# see https://gist.github.com/tgfrerer/8e2d973ed0cfdd514de6
		local FAT_LDFLAGS="-arch arm64 -arch x86_64 -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot ${SDK_PATH}"

		./configure LDFLAGS="${FAT_LDFLAGS} -flto ${INCLUDE_ZLIB_LIBS}" \
				CFLAGS="-O3 ${FAT_LDFLAGS} ${INCLUDE_ZLIB}" \
				--prefix=$BUILD_ROOT_DIR \
				--disable-dependency-tracking \
                --disable-arm-neon \
                --enable-static \
                --disable-shared
		make clean
		make install
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP

		mkdir build
		cd build

		ROOT=${PWD}/..
		# export INCLUDE_ZLIB="-I$ROOT/zlib/build/"
		# export INCLUDE_ZLIB_LIBS="-L$ROOT/zlib/build/ -lz"


		export ZLIB_ROOT=../zlib
		mkdir -p build

		if [ $VS_VER == 15 ] ; then
			if [ $ARCH == 32 ] ; then
				cmake .. -G "Visual Studio $VS_VER Win32" -DZLIB_ROOT=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == 64 ] ; then
				cmake .. -G "Visual Studio $VS_VER Win64" -DZLIB_ROOT=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == "ARM" ] ; then
				cmake .. -G "Visual Studio $VS_VER ARM" -DZLIB_ROOT=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == "ARM64" ] ; then
				cmake .. -G "Visual Studio $VS_VER ARM64" -DZLIB_ROOT=${ZLIB_ROOT}
				cmake --build . --config Release
			fi
		else
			if [ $ARCH == 32 ] ; then
				cmake .. -G "Visual Studio $VS_VER" -A Win32 -DZLIB_ROOT=${ZLIB_ROOT} -DZLIB_LIBRARY=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == 64 ] ; then
				cmake .. -G "Visual Studio $VS_VER" -A x64 -DZLIB_ROOT=${ZLIB_ROOT} -DZLIB_LIBRARY=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == "ARM" ] ; then
				cmake .. -G "Visual Studio $VS_VER" -A ARM -DZLIB_ROOT=${ZLIB_ROOT} -DZLIB_LIBRARY=${ZLIB_ROOT}
				cmake --build . --config Release
			elif [ $ARCH == "ARM64" ] ; then
				cmake .. -G "Visual Studio $VS_VER" -A ARM64 -DZLIB_ROOT=${ZLIB_ROOT} -DZLIB_LIBRARY=${ZLIB_ROOT}
				cmake --build . --config Release
			fi
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
		elif [ "$ARCH" == 64 ]; then
			mkdir -p $1/../cairo/lib/vs/x64/
			cp ../libpng/projects/vs2015/x64/LIB\ Release/libpng.lib $1/../cairo/lib/vs/x64/
		elif [ "$ARCH" == "ARM64" ]; then
			mkdir -p $1/../cairo/lib/vs/ARM64/
			cp ../libpng/projects/vs2015/ARM64/LIB\ Release/libpng.lib $1/../cairo/lib/vs/ARM64/
		fi
	else
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE
		cp -v ${BUILD_ROOT_DIR}/lib/libpng.a $1/lib/$TYPE/libpng.a
		cp -v ${BUILD_ROOT_DIR}/lib/libpng16.a $1/lib/$TYPE/libpng16.a
		# copy license file
		rm -rf $1/license # remove any older files if exists
		mkdir -p $1/license
		cp -v LICENSE $1/license/
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
