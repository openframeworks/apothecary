#!/usr/bin/env bash
#
# the official PNG reference library
# http://libpng.org/pub/png/libpng.html

# define the version
MAJOR_VER=16
VER=1.6.40
WIN_VER=1640

# tools for git use
GIT_URL=http://git.code.sf.net/p/libpng/code
GIT_TAG=v$VER
URL=https://github.com/glennrp/libpng/archive/refs/tags/v1.6.40
SHA=
WINDOWS_URL=https://github.com/glennrp/libpng/archive/refs/tags/v1.6.40

FORMULA_TYPES=( "osx" "vs" )

FORMULA_DEPENDS=( "zlib" ) 


# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"

	if [ "$TYPE" == "vs" ] ; then
		downloader "${URL}.zip"
		unzip -q "v${VER}.zip"
		mv "libpng-${VER}" libpng
		rm "v${VER}.zip"
	else 
		downloader "${URL}.tar.gz"
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
		#cp -vr $FORMULA_DIR/vs2015 projects/
		# ls ../zlib
		# ls ../zlib/Release
		# cp ../zlib/Release/zlib.lib ../zlib/zlib.lib
	fi


	
}

# executed inside the lib src dir
function build() {

	
	if [ "$TYPE" == "osx" ] ; then
		ROOT=$(realpath ${PWD}/..)
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

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

		LIBS_ROOT=$(realpath $LIBS_DIR)


		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	    echoVerbose "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 

	    mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"

		Z_ROOT="$LIBS_ROOT/zlib/"
		Z_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		Z_LIBRARY="$LIBS_ROOT/zlib/$TYPE/$PLATFORM/zlib.lib"

		DEFS="
		    -DCMAKE_BUILD_TYPE=Release \
		    -DCMAKE_VS_WINDOWS_TARGET_PLATFORM_VERSION=10.0.190410.0 \
		    -DCMAKE_SYSTEM_VERSION=10.0.190410.0 \
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DZLIB_ROOT=${Z_ROOT} \
		    -DZLIB_LIBRARY=${Z_LIBRARY} \
		    -DZLIB_INCLUDE=${Z_INCLUDE_DIR} \
		    -DPNG_TESTS=OFF \
		    -DPNG_SHARED=OFF \
		    -DPNG_STATIC=ON \
		    -DBUILD_SHARED_LIBS=ON \
		    -DCMAKE_INSTALL_PREFIX=Release \
		    -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
		    -DCMAKE_INSTALL_INCLUDEDIR=include \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin \
		    -DCMAKE_TEMPORARY_OUTPUT_DIRECTORY=/temp \
		    -DCMAKE_INTERMEDIATE_OUTPUT_DIRECTORY=/intermediate"

	cmake .. ${DEFS} \
	    -A "${PLATFORM}" \
	    -G "${GENERATOR_NAME}" \
	    -D CMAKE_VERBOSE_MAKEFILE=ON \
	    -D BUILD_SHARED_LIBS=ON 

	cmake --build . --config Release --target install

	cd ..	
		
	fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	mkdir -p $1/include
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		echo "libpng copy"
    	cp -v "build_${TYPE}_${ARCH}/Release/lib/libpng16_static.lib" $1/lib/$TYPE/$PLATFORM/libpng.lib
    	cp -RvT "build_${TYPE}_${ARCH}/Release/include" $1/include

	else
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE
		cp -v ${BUILD_ROOT_DIR}/lib/libpng.a $1/lib/$TYPE/libpng.a
		cp -v ${BUILD_ROOT_DIR}/lib/libpng16.a $1/lib/$TYPE/libpng16.a			
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE $1/license/
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

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "libpng" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "libpng" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
