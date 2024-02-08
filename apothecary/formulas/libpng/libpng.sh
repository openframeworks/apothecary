#!/usr/bin/env bash
#
# the official PNG reference library
# http://libpng.org/pub/png/libpng.html

# define the version
MAJOR_VER=16
VER=1.6.40
WIN_VER=1644

# tools for git use
GIT_URL=http://git.code.sf.net/p/libpng/code
GIT_TAG=v$VER
#URL=https://github.com/glennrp/libpng/archive/refs/tags/v1.6.40 # Glenn Randers-Pehrson 
URL=https://github.com/glennrp/libpng/archive/refs/tags/v1.6.40
SHA=
WINDOWS_URL=https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.40

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" )

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
		echo https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.42.tar.gz
		downloader "${URL}.tar.gz"
		tar -xf "v${VER}.tar.gz"
		mv "libpng-${VER}" libpng
		rm "v${VER}.tar.gz"
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
	fi


	
}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)
	
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

		DEFS="-DCMAKE_BUILD_TYPE=Release \
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
		    -DZLIB_ROOT=${ZLIB_ROOT} \
		    -DZLIB_LIBRARY=${ZLIB_INCLUDE_DIR} \
		    -DZLIB_INCLUDE_DIRS=${ZLIB_LIBRARY} \
		    -DPNG_BUILD_ZLIB=OFF \
		    -DPNG_TESTS=OFF \
		    -DPNG_SHARED=OFF \
		    -DPNG_STATIC=ON \
		    -DBUILD_SHARED_LIBS=ON \
		    -DPNG_HARDWARE_OPTIMIZATIONS=ON \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include"

			cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..	
	elif [ "$TYPE" == "vs" ] ; then
		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	  echoVerbose "--------------------"
	  GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 

	  mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"

		Z_ROOT="$LIBS_ROOT/zlib/"
		Z_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		Z_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

		DEFS="
				-DCMAKE_BUILD_TYPE=Release \
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
				-DCMAKE_INSTALL_LIBDIR=lib"

  env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
  env CFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
	cmake .. ${DEFS} \
			-B . \
	    -A "${PLATFORM}" \
	    -G "${GENERATOR_NAME}" \
	    ${CMAKE_WIN_SDK} \
	    -UCMAKE_CXX_FLAGS \
	    -UCMAKE_C_FLAGS \
	    -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
      -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	    -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
	    -D BUILD_SHARED_LIBS=ON

	cmake --build . --config Release  --target install

	cd ..	
		
	fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	mkdir -p $1/include
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		mkdir -p $1/include
		cp -v "build_${TYPE}_${ARCH}/Release/lib/libpng16_static.lib" $1/lib/$TYPE/$PLATFORM/libpng.lib
		cp -RT "build_${TYPE}_${ARCH}/Release/include/" $1/include
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		mkdir -p $1/include
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libpng16.a" $1/lib/$TYPE/$PLATFORM/libpng16.a
		# cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libpng.a" $1/lib/$TYPE/$PLATFORM/libpng.a
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
	else
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/libpng16.a" $1/lib/$TYPE/$PLATFORM/libpng16.a
		cp -v "build_${TYPE}_${PLATFORM}/Release/libpng.a" $1/lib/$TYPE/$PLATFORM/libpng.a
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include	
	fi

	# copy license file
	if [ -d "$1/license" ]; then
    rm -rf $1/license
  fi
	mkdir -p $1/license
	cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
    if [ -d "build_${TYPE}_${ARCH}" ]; then
        rm -r build_${TYPE}_${ARCH}     
    fi
	elif [ "$TYPE" == "android" ] ; then
		if [ -d "build_${TYPE}_${ABI}" ]; then
	        rm -r build_${TYPE}_${ABI}     
	  fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
	        rm -r build_${TYPE}_${PLATFORM}     
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
