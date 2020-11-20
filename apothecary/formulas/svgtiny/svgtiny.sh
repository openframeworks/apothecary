#!/usr/bin/env bash
#
# svgtiny
# Libsvgtiny is an implementation of SVG Tiny, written in C
# http://www.netsurf-browser.org/projects/libsvgtiny/
#
# uses a makeifle build system

FORMULA_TYPES=( "linux64" "linuxarmv6l" "linuxarmv7l" "osx" "vs" "ios" "tvos" "android" "emscripten" "msys2" )

#dependencies
FORMULA_DEPENDS=( "libxml2" )

# define the version by sha
VER=0.1.4

# tools for git use
GIT_URL=git://git.netsurf-browser.org/libsvgtiny.git
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	git clone -b release/$VER --depth 1 git://git.netsurf-browser.org/libsvgtiny.git
    mv libsvgtiny svgtiny
    cd svgtiny

    git clone -b release/0.3.0 --depth 1 git://git.netsurf-browser.org/libdom.git
    git clone -b release/0.2.3 --depth 1 git://git.netsurf-browser.org/libparserutils.git
    git clone -b release/0.3.0 --depth 1 git://git.netsurf-browser.org/libwapcaplet.git
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "msys2" ] || [ "$TYPE" == "vs" ]; then
		dos2unix $FORMULA_DIR/libparseutils.patch
		dos2unix $FORMULA_DIR/libdom.patch
	fi

	cd libparserutils
    if git apply $FORMULA_DIR/libparseutils.patch  --check; then
        git apply $FORMULA_DIR/libparseutils.patch
    fi
    cd ..

	cd libdom
    if git apply $FORMULA_DIR/libdom.patch  --check; then
        git apply $FORMULA_DIR/libdom.patch
    fi
	cd ..

	if [ "$TYPE" == "vs" ]; then
		cp $FORMULA_DIR/libwapcaplet.h libwapcaplet/include/libwapcaplet/
		cp -r $FORMULA_DIR/vs2015 ./
		cp -r $FORMULA_DIR/vs2017 ./
	else
    	cp $FORMULA_DIR/Makefile .
	fi

	#On MINGW64, gperf generates svgtiny_color_lookup(register const char *str, register size_t len);
	#but it is defined int the header as svgtiny_color_lookup(register const char *str, register unsigned int len);
	 if [ "$TYPE" == "msys2" ]; then
	 	sed -i.tmp "s|unsigned int len|size_t len|" src/svgtiny_internal.h
	 fi

    gperf src/colors.gperf > src/svg_colors.c
    cp -rf libdom/bindings libdom/include/dom/
}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ] ; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi
        export CFLAGS="$(pkg-config libxml-2.0 --cflags)"
        make clean
	    make -j${PARALLEL_MAKE}

	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		if [ $VS_VER -eq 14 ]; then
			cd vs2015
			if [ $ARCH == 32 ] ; then
				vs-build svgtiny.sln Build "Release|x86"
			else
				vs-build svgtiny.sln Build "Release|x64"
			fi
		elif [ $VS_VER -eq 15 ]; then
			cd vs2017
			if [ $ARCH == 32 ] ; then
				vs-build svgtiny.sln Build "Release|x86"
			else
				vs-build svgtiny.sln Build "Release|x64"
			fi
		else
			echo "VS Version not supported yet"
		fi

	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI
        export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
        make clean
	    make -j${PARALLEL_MAKE}

	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
        make clean
	    make -j${PARALLEL_MAKE}

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
            export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
            make clean
	        make -j${PARALLEL_MAKE}
            mv libsvgtiny.a libsvgtiny_$IOS_ARCH.a
        done

        if [ "$TYPE" == "ios" ]; then
            lipo -create libsvgtiny_x86_64.a \
                         libsvgtiny_armv7.a \
                         libsvgtiny_arm64.a \
                        -output libsvgtiny.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create libsvgtiny_x86_64.a \
                         libsvgtiny_arm64.a \
                        -output libsvgtiny.a
        fi


	elif [ "$TYPE" == "emscripten" ]; then
        emmake make clean
	    emmake make -j${PARALLEL_MAKE} CUSTOM_CFLAGS="-I$LIBS_DIR/libxml2/include"

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE
	cp -Rv include/* $1/include

	if [ "$TYPE" == "vs" ] ; then
		if [ $VS_VER -eq 14 ]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "vs2015/Release/svgtiny.lib" $1/lib/$TYPE/Win32/svgtiny.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "vs2015/x64/Release/svgtiny.lib" $1/lib/$TYPE/x64/svgtiny.lib
			fi
		elif [ $VS_VER -eq 15 ]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "vs2017/Release/svgtiny.lib" $1/lib/$TYPE/Win32/svgtiny.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "vs2017/x64/Release/svgtiny.lib" $1/lib/$TYPE/x64/svgtiny.lib
			fi
		else
			echo "VS Version not supported yet"
		fi

	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv libsvgtiny.a $1/lib/$TYPE/svgtiny.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
		cp -Rv libsvgtiny.a $1/lib/$TYPE/$ABI/libsvgtiny.a
	elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "emscripten" ] || [ "$TYPE" == "msys2" ]; then
		# copy lib
		cp -Rv libsvgtiny.a $1/lib/$TYPE/libsvgtiny.a
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
