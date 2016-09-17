#! /bin/bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" "ios" "android" )

#dependencies
FORMULA_DEPENDS=( "openssl" )

# define the version by sha
VER=7_50_2

# tools for git use
GIT_URL=https://github.com/curl/curl.git
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	curl -Lk https://github.com/curl/curl/archive/curl-$VER.tar.gz -o curl-$VER.tar.gz
	tar -xf curl-$VER.tar.gz
	mv curl-curl-$VER curl
	rm curl*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
}

# executed inside the lib src dir
function build() {
	rm -f CMakeCache.txt
	local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

	if [ "$TYPE" == "vs" ] ; then
		local OF_LIBS_OPENSSL_ABS_PATH=$(cd $(dirname $OF_LIBS_OPENSSL); pwd)/$(basename $OF_LIBS_OPENSSL)
		local OPENSSL_INCLUDE=$OF_LIBS_OPENSSL_ABS_PATH/include
		local OPENSSL_LIBS=$OF_LIBS_OPENSSL_ABS_PATH/lib/
        EXTRA_CONFIG="-DCMAKE_USE_OPENSSL=ON -DCURL_STATICLIB=ON -DBUILD_TESTING=OFF -DCMAKE_LIBRARY_PATH=$OPENSSL_LIBS -DCMAKE_INCLUDE_PATH=$OPENSSL_INCLUDE"
		if [ $ARCH == 32 ] ; then
			mkdir -p build_vs_32
			cd build_vs_32
			cmake .. -G "Visual Studio $VS_VER" $EXTRA_CONFIG
			#vs-build "curl.sln"
            cmake --build . --config "Release|Win32" --clean-first
		elif [ $ARCH == 64 ] ; then
			mkdir -p build_vs_64
			cd build_vs_64
			cmake .. -G "Visual Studio $VS_VER Win64" $EXTRA_CONFIG
			#vs-build "curl.sln" Build "Release|x64"
            cmake --build . --config "Release|Win64"--clean-first
		fi
	elif [ "$TYPE" == "android" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/curl/build/$TYPE/$ABI
        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE/$ABI
	    source ../../android_configure.sh $ABI
	    if [ "$ARCH" == "armv7" ]; then
            HOST=armv7a-linux-android
        elif [ "$ARCH" == "x86" ]; then
            HOST=x86-linux-android
        fi
        ./buildconf
	    ./configure --prefix=$BUILD_TO_DIR --host $HOST --with-ssl=$OPENSSL_DIR --enable-static=yes --enable-shared=no 
        sed -i "s/#define HAVE_GETPWUID_R 1/\/\* #undef HAVE_GETPWUID_R \*\//g" lib/curl_config.h
        make clean
	    make -j${PARALLEL_MAKE}
	    make install
    else
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib 
            export CFLAGS=-I$SYSROOT/usr/include
        fi
        if [ "$TYPE" == "osx" ]; then
            export CFLAGS="-arch i386 -arch x86_64"
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
		./configure --with-ssl=$OPENSSL_DIR
        make clean
	    make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/curl

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
		cp -Rv include/* $1/include
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v build_vs_32/src/Release/curl.lib $1/lib/$TYPE/Win32/curl.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v build_vs_64/src/Release/curl.lib $1/lib/$TYPE/x64/curl.lib
		fi		
	elif [ "$TYPE" == "osx" ] ; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/curl/* $1/include/curl/
		# copy lib
		cp -Rv lib/.libs/libcurl.a $1/lib/$TYPE/curl.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/curl/* $1/include/curl/
		# copy lib
		cp -Rv build/$TYPE/$ABI/lib/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
    else
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/curl/* $1/include/curl/
		# copy lib
		cp -Rv lib/.libs/libcurl.a $1/lib/$TYPE/libcurl.a
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
