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
VER=2.2.0

# tools for git use
GIT_URL=https://github.com/nigels-com/glew.git
GIT_TAG=glew-$VER
URL=https://github.com/nigels-com/glew/releases/download/${GIT_TAG}

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"

	downloader "${URL}/${GIT_TAG}.tgz"
	tar -xf glew-$VER.tgz
	mv glew-$VER glew
	rm glew-$VER.tgz


}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	. "$DOWNLOADER_SCRIPT"
	downloader https://raw.githubusercontent.com/ORDIS-Co-Ltd/glew/a668da0183f44b550de5b37e77ba2e280b0ae8b0/build/cmake/CMakeLists.txt
	cp -f ./CMakeLists.txt ./build/cmake/CMakeLists.txt
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
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
		echo "--------------------"
		GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"

		DEFS="-DLIBRARY_SUFFIX=${ARCH}"

		cmake ../build/cmake ${DEFS} \
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
		    -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DBUILD_SHARED_LIBS=ON \
		    -DCMAKE_BUILD_TYPE=Release \
		    -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DGLEW_X11=ON \
		    -DGLEW_EGL=OFF \
		    -DBUILD_UTILS=ON \
		    -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
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
	if [ "$TYPE" == "osx" ] ; then
		cp -Rv include/* $1/include
		mkdir -p $1/lib/$TYPE
		cp -v libGLEW.a $1/lib/$TYPE/glew.a

	elif [ "$TYPE" == "vs" ] ; then
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/		
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		mkdir -p $1/bin/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/bin/glew32.dll" $1/lib/$TYPE/$PLATFORM/glew32.dll
        cp -v "build_${TYPE}_${ARCH}/Release/lib/glew32.lib" $1/lib/$TYPE/$PLATFORM/glew32.lib
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
		rm -rf build_${TYPE}_${ARCH}
		rm -rf $1/lib/$TYPE/*
	else
		make clean
		rm -f *.a *.lib
	fi
}
