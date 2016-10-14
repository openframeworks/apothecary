#!/usr/bin/env bash
#
# pugixml
# pugixml is a c++ xml parser
# http://pugixml.org/
#
# uses a makeifle build system

FORMULA_TYPES=( "emscripten" "osx" "vs" "ios" "tvos" "android" )

# define the version by sha
VER=1.7

# tools for git use
GIT_URL=https://github.com/zeux/pugixml
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	wget http://github.com/zeux/pugixml/releases/download/v$VER/pugixml-$VER.tar.gz 
    tar xzf pugixml-$VER.tar.gz
    mv pugixml-$VER pugixml
    rm pugixml-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "emscripten" ]; then
        rm -f libpugixml.a

		# Compile the program
		emcc -O2 \
			 -Wall \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o src/pugixml.bc
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd scripts
		if [ $ARCH == 32 ] ; then
			vs-build pugixml_vs2015.vcxproj Build "Release|Win32"
		else
			vs-build pugixml_vs2015.vcxproj Build "Release|x64"
		fi
	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI
		# Compile the program
		$CXX -O2 \
			 -Wall \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o src/pugixml.o
        $AR ruv libpugixml.a src/pugixml.o
	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
        make clean
	    make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
        fi
		for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
    	    source ../../ios_configure.sh $TYPE $IOS_ARCH
            export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
            make clean
	        make -j${PARALLEL_MAKE}
            mv libsvgtiny.a libsvgtiny_$IOS_ARCH.a
        done

        if [ "$TYPE" == "ios" ]; then
            lipo -create libsvgtiny_i386.a \
                         libsvgtiny_x86_64.a \
                         libsvgtiny_armv7.a \
                         libsvgtiny_arm64.a \
                        -output libsvgtiny.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create libsvgtiny_x86_64.a \
                         libsvgtiny_arm64.a \
                        -output libsvgtiny.a
        fi
    else
        echo "building other for $TYPE"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
		./configure --with-ssl=$OPENSSL_DIR --enable-static --disable-shared
        make clean
	    make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
		cp -Rv src/*.hpp $1/include/
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v "build/Win32/VC14/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/Win32/libcurl.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v "build/Win64/VC14/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/x64/curl.lib
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv src/*.hpp $1/include/
		# copy lib
		cp -Rv libpugixml.a $1/lib/$TYPE/pugixml.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# Standard *nix style copy.
		# copy headers
		cp -Rv src/*.hpp $1/include/
		# copy lib
		cp -Rv libpugixml.a $1/lib/$TYPE/$ABI/libpugixml.a
	elif [ "$TYPE" == "emscripten" ] ; then
	    mkdir -p $1/lib/$TYPE
		# Standard *nix style copy.
		# copy headers
		cp -Rv src/*.hpp $1/include/
		# copy lib
		cp -Rv libpugixml.bc $1/lib/$TYPE/libpugixml.bc
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
