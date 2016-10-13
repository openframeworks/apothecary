#!/usr/bin/env bash
#
# svgtiny
# Libsvgtiny is an implementation of SVG Tiny, written in C
# http://www.netsurf-browser.org/projects/libsvgtiny/
#
# uses a makeifle build system

FORMULA_TYPES=( "linux64" "osx" "vs" "ios" "tvos" "android" )

#dependencies
FORMULA_DEPENDS=( "libxml2" )

# define the version by sha
VER=0.1.4

# tools for git use
GIT_URL=git://git.netsurf-browser.org/libsvgtiny.git
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	git clone git://git.netsurf-browser.org/libsvgtiny.git
    mv libsvgtiny svgtiny
    cd svgtiny
    git checkout release/$VER

    git clone git://git.netsurf-browser.org/libdom.git
    cd libdom 
    git checkout release/0.3.0
    cd ..

    git clone git://git.netsurf-browser.org/libparserutils.git  
    cd libparserutils
    git checkout release/0.2.3
    cd ..

    git clone git://git.netsurf-browser.org/libwapcaplet.git
    cd libwapcaplet
    git checkout release/0.3.0
    cd ..        
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    cd libparserutils
    if git apply $FORMULA_DIR/libparseutils.patch  --check; then
        git apply $FORMULA_DIR/libparseutils.patch  
    fi


    if [ "$TYPE" != "linux" ] && [ "$TYPE" != "linux64" ] && [ "$TYPE" != "linuxarmv6" ] && [ "$TYPE" != "linuxarmv7" ] ; then   
        apothecaryDepend download libxml2
        apothecaryDepend prepare libxml2
        apothecaryDepend build libxml2
        apothecaryDepend copy libxml2
    fi
    if [ "$TYPE" != "linux" ] && [ "$TYPE" != "linux64" ] && [ "$TYPE" != "linuxarmv6" ] && [ "$TYPE" != "linuxarmv7" ]; then
        cp $FORMULA_DIR/expat.h src/
        cp $FORMULA_DIR/expat_external.h src/
    fi
}

# executed inside the lib src dir
function build() {
    cp $FORMULA_DIR/Makefile .
    cp -rf libdom/bindings libdom/include/dom/
    
    if [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxarmv6" ] || [ "$TYPE" == "linuxarmv7" ] ; then      
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        else
            export CFLAGS="$(pkg-config libxml-2.0 --cflags)"  
        fi
        make clean
	    make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		local OF_LIBS_OPENSSL_ABS_PATH=$(realpath ../openssl)
		export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
		export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/
		PATH=$OPENSSL_LIBRARIES:$PATH cmd //c "projects\\generate.bat vc14"
		cd projects/Windows/VC14/lib
		if [ $ARCH == 32 ] ; then
			PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|Win32"
		else
			PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|x64"
		fi

	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI
        export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
        make clean
	    make -j${PARALLEL_MAKE}
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
		cp -Rv include/* $1/include
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
		cp -Rv include/* $1/include/
		# copy lib
		cp -Rv libsvgtiny.a $1/lib/$TYPE/svgtiny.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/* $1/include/
		# copy lib
		cp -Rv libsvgtiny.a $1/lib/$TYPE/$ABI/libsvgtiny.a
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
