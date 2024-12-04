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
FORMULA_DEPENDS=( )

# define the version
VER=2.2.0
BUILD_ID=1
DEFINES=""
SHA1=22d6e9b9e691080eb6313407dbf51cfebc3345ea

# tools for git use
GIT_URL=https://github.com/nigels-com/glew.git
GIT_TAG=glew-$VER
URL=https://github.com/nigels-com/glew/releases/download/${GIT_TAG}

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
	downloader "${URL}/${GIT_TAG}.tgz"

	local CHECKSHA=$(shasum glew-$VER.tgz | awk '{print $1}')
    if [ "$CHECKSHA" != "$SHA1" ] ; then
        echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
        exit 1
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi
	tar -xf glew-$VER.tgz
	mv glew-$VER glew
	rm glew-$VER.tgz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	. "$DOWNLOADER_SCRIPT"
	cp -f $FORMULA_DIR/CMakeLists.txt ./build/cmake/CMakeLists.txt
}

# executed inside the lib src dir
function build() {

	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

		echo "building $TYPE | $PLATFORM"
        echo "--------------------"
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o 
		cmake  ../build/cmake \
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
		    -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
			-DPLATFORM=$PLATFORM \
			-DENABLE_BITCODE=OFF \
			-DENABLE_ARC=OFF \
			-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
			-DENABLE_VISIBILITY=OFF \
			-DGLEW_X11=ON \
		    -DGLEW_EGL=OFF \
		    -DBUILD_UTILS=OFF \
		    -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include 
		cmake --build . --config Release --target install
        cd ..

	elif [ "$TYPE" == "vs" ] ; then
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN C_FLAGS: ${VS_C_FLAGS} CONVENTION: ${CALLING_CONVENTION} SDK:${CMAKE_WIN_SDK}"
		echo "--------------------"
		GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"


		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"

		rm -f CMakeCache.txt *.lib *.o 
		DEFS="-DLIBRARY_SUFFIX=${ARCH}"
		
		cmake ../build/cmake ${DEFS} \
		    -DCMAKE_C_STANDARD=${C_STANDARD} \
		    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		    -DCMAKE_C_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS} ${CALLING_CONVENTION}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS} ${CALLING_CONVENTION}" \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DBUILD_SHARED_LIBS=OFF \
		    -DCMAKE_BUILD_TYPE=Release \
		    -DGLEW_X11=ON \
		    -DGLEW_EGL=OFF \
		    -DBUILD_UTILS=OFF \
		    -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            ${CMAKE_WIN_SDK} \
		    -A "${PLATFORM}" \
		    -G "${GENERATOR_NAME}" 

		cmake --build . --config Release --target install
		cd ..

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

	# libs
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v -r build_${TYPE}_${PLATFORM}/Release/include/* $1/include
		cp -v -r build_${TYPE}_${PLATFORM}/Release/lib/libGLEW.a $1/lib/$TYPE/$PLATFORM/libGLEW.a
		. "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/$PLATFORM/libGLEW.a glew.pkl
	elif [ "$TYPE" == "vs" ] ; then
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/		
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        # cp -v "build_${TYPE}_${ARCH}/Release/bin/glew32.dll" $1/lib/$TYPE/$PLATFORM/glew32_s.dll
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libglew32.lib" $1/lib/$TYPE/$PLATFORM/libglew32.lib
        . "$SECURE_SCRIPT"
        secure $1/lib/$TYPE/$PLATFORM/libglew32.lib glew.pkl
	elif [ "$TYPE" == "msys2" ] ; then
		# TODO: add cb formula
		mkdir -p $1/lib/$TYPE
		cp -v lib/libglew32.a $1/lib/$TYPE
	fi

	# copy license files
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then	
		rm -rf build_${TYPE}_${ARCH}
		rm -rf $1/lib/$TYPE/*
	else
		make clean
		rm -f *.a *.lib
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "glew" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
