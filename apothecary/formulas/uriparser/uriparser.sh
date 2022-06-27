#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" "emscripten" )


# define the version by sha
VER=0.8.5

# tools for git use
GIT_URL=git://git.code.sf.net/p/uriparser/git
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv --no-check-certificate https://github.com/uriparser/uriparser/releases/download/uriparser-$VER/uriparser-$VER.tar.bz2
	tar -xjf uriparser-$VER.tar.bz2
	mv uriparser-$VER uriparser
	rm uriparser*.tar.bz2
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "vs" ] ; then
		cp -vr $FORMULA_DIR/vs2015 win32/
	fi
}

# executed inside the lib src dir
function build() {
	rm -f CMakeCache.txt

	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd win32/vs2015

		if [[ $VS_VER -gt 14 ]]; then
			vs-upgrade uriparser.sln
		fi

		if [ $ARCH == 32 ] ; then
			vs-build uriparser.sln Build "Release|Win32"
		elif [ $ARCH == 64 ] ; then
			vs-build uriparser.sln Build "Release|x64"
		fi

	elif [ "$TYPE" == "android" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE/$ABI
	    source ../../android_configure.sh $ABI
	    if [ "$ARCH" == "armv7" ]; then
            HOST=armv7a-linux-android
        elif [ "$ARCH" == "arm64" ]; then
            HOST=aarch64-linux-android
        elif [ "$ARCH" == "x86" ]; then
            HOST=x86-linux-android
        fi
	    ./configure --prefix=$BUILD_TO_DIR --host $HOST --disable-test --disable-doc --enable-static=yes --enable-shared=no
        make clean
	    make -j${PARALLEL_MAKE}
	    make install
	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
	    local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE

		./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared
        make clean
		make -j${PARALLEL_MAKE}
	    make install
	elif [ "$TYPE" == "emscripten" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE
		emconfigure ./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared
		echo "int main(){return 0;}" > tool/uriparse.c
        emmake make clean
		emmake make -j${PARALLEL_MAKE}
	    emmake make install
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
        fi

		for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
    	    source ../../ios_configure.sh $TYPE $IOS_ARCH
            local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE/$IOS_ARCH
            ./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared --host=$HOST --target=$HOST
            make clean
            make -j${PARALLEL_MAKE}
            make install
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "${TYPE}" == "ios" ]; then
            lipo -create build/$TYPE/x86_64/lib/liburiparser.a \
                         build/$TYPE/armv7/lib/liburiparser.a \
                         build/$TYPE/arm64/lib/liburiparser.a \
                        -output build/$TYPE/lib/liburiparser.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create build/$TYPE/x86_64/lib/liburiparser.a \
                         build/$TYPE/arm64/lib/liburiparser.a \
                        -output build/$TYPE/lib/liburiparser.a
        fi
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/uriparser

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		else
			PLATFORM="x64"
		fi
		cp -Rv include/* $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM
		cp -v win32/uriparser.lib $1/lib/$TYPE/$PLATFORM/uriparser.lib
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		cp -Rv build/$TYPE/lib/liburiparser.a $1/lib/$TYPE/uriparser.a
	elif [ "$TYPE" == "emscripten" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		cp -Rv build/$TYPE/lib/liburiparser.a $1/lib/$TYPE/liburiparser.a
    elif [ "$TYPE" == "android" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		cp -Rv build/$TYPE/$ABI/lib/*.a $1/lib/$TYPE/$ABI
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
	else
		make clean
	fi
}
