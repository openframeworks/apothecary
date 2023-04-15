#!/usr/bin/env bash
#
# Cairo
# 2D graphics library with support for multiple output devices
# http://www.cairographics.org/
#
# has an autotools build system and requires pkg-config, libpng, & pixman,
# dependencies have their own formulas in cairo/depends
#
# following http://www.cairographics.org/end_to_end_build_for_mac_os_x,
# we build and install dependencies into a subfolder of cairo by setting the
# prefix (install location) and use a custom copy of pkg-config which returns
# the dependent lib cflags/ldflags for that prefix (cairo/apothecary-build)

FORMULA_TYPES=( "osx" "vs" )

FORMULA_DEPENDS=( "pkg-config" "zlib" "libpng" "pixman" "freetype"  )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
FORMULA_DEPENDS_MANUAL=1

# define the version
VER=1.17.4

SHA1=68712ae1039b114347be3b7200bc1c901d47a636

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/cairo
GIT_TAG=$VER
URL=https://www.cairographics.org/snapshots/


# download the source code and unpack it into LIB_NAME
function download() {

	. "$DOWNLOADER_SCRIPT"

	downloader https://cairographics.org/snapshots/cairo-$VER.tar.xz
	local CHECKSHA=$(shasum cairo-$VER.tar.xz | awk '{print $1}')
	if [ "$CHECKSHA" != "$SHA1" ] ; then
    	echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
    	exit
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi
	tar -xf cairo-$VER.tar.xz
	mv cairo-$VER cairo
	rm cairo-$VER.tar.xz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# manually download dependencies

	echo
	#echoInfo " Current PATH set to: $PATH"
	echo

	apothecaryDependencies download

	if [ "$TYPE" == "vs" ] ; then

		apothecaryDepend prepare zlib
		apothecaryDepend build zlib
		apothecaryDepend copy zlib
		apothecaryDepend prepare libpng
		apothecaryDepend build libpng
		apothecaryDepend copy libpng
		apothecaryDepend prepare pixman
		apothecaryDepend build pixman
		apothecaryDepend copy pixman
		apothecaryDepend prepare freetype
		apothecaryDepend build freetype
		apothecaryDepend copy freetype

		echo "copying from $PWD"
		if [ "$ARCH" == 32 ]; then
			cp ../libpng/projects/vs2015/Win32_LIB_Release/libpng.lib ../libpng/libpng.lib
		elif [ "$ARCH" == 64 ]; then
			cp ../libpng/projects/vs2015/x64/LIB\ Release/libpng.lib ../libpng/libpng.lib
		elif [ "$ARCH" == "ARM" ]; then
			cp ../libpng/projects/vs2015/ARM/LIB\ Release/libpng.lib ../libpng/libpng.lib
		fi
		ls ../zlib
		ls ../zlib/Release
		cp ../zlib/Release/zlib.lib ../zlib/zlib.lib
	else
		# generate the configure script if it's not there
		
		# Build and copy all dependencies in preparation
		apothecaryDepend download pkg-config
		apothecaryDepend prepare pkg-config
		apothecaryDepend build pkg-config
		apothecaryDepend copy pkg-config
		apothecaryDepend download zlib
		apothecaryDepend prepare zlib
		apothecaryDepend build zlib
		apothecaryDepend copy zlib
		apothecaryDepend download libpng
		apothecaryDepend prepare libpng
		apothecaryDepend build libpng
		apothecaryDepend copy libpng
		apothecaryDepend download pixman
		apothecaryDepend build pixman
		apothecaryDepend copy pixman
		apothecaryDepend download freetype
		apothecaryDepend prepare freetype
		apothecaryDepend build freetype
		apothecaryDepend copy freetype
	fi
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "vs" ] ; then
		ROOT=${PWD}/..
		export INCLUDE="$ROOT/zlib"
		export INCLUDE="$INCLUDE;$ROOT/libpng"
		export INCLUDE="$INCLUDE;$ROOT/pixman/pixman"
		export INCLUDE="$INCLUDE;$ROOT/cairo/boilerplate"
		export INCLUDE="$INCLUDE;$ROOT/cairo/src"
		export LIB="$ROOT/zlib/Release/"
		export LIB="$LIB;$ROOT/libpng/projects/visualc71/Win32_LIB_Release"
		sed -i "s/-MD/-MT/" build/Makefile.win32.common
		sed -i "s/zdll.lib/zlib.lib/" build/Makefile.win32.common
		# systeminfo
		# which link
		# echo "PATH=$PATH"
		# ls "/c/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Tools/MSVC/14.12.25827/bin/HostX64/x64"
		# find "/c/Program Files (x86)/Microsoft Visual Studio/2017/" -iname link.exe
		# exit 1
		with_vs_env "make -f Makefile.win32 \"CFG=release\""
	elif [ "$TYPE" == "osx" ] ; then

        # needed for travis FREETYPE_LIBS configure var forces cairo to search this location for freetype 
        ROOT=${PWD}/..

        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        SYSROOT="-isysroot ${SDK_PATH}"
        export SDK=macosx
        export DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER}
        export ARCHS="-arch arm64 -arch x86_64"

        export OF_LIBS_ABS_PATH=$(realpath ${LIBS_DIR}/)

        # cp -v ${OF_LIBS_ABS_PATH}/freetype/lib/${TYPE}/freetype.a ${BUILD_ROOT_DIR}/lib/freetype.a # this works! 
        # cp -Rv ${OF_LIBS_ABS_PATH}/freetype/include/* ${BUILD_ROOT_DIR}/include/ # this works! 

        cp ${OF_LIBS_ABS_PATH}/freetype/lib/osx/freetype.a ${OF_LIBS_ABS_PATH}/freetype/lib/osx/libfreetype.a

        FREETYPE_LIB_PATH="-L${OF_LIBS_ABS_PATH}/freetype/lib/osx -lfreetype"

        echo "FreeType location: $FREETYPE_LIB_PATH"
        echo "PKG_CONFIG location: $BUILD_ROOT_DIR/bin/pkg-config"

        export PATH="$PATH;$BUILD_ROOT_DIR;$BUILD_ROOT_DIR/lib;$BUILD_ROOT_DIR/lib/pkgconfig;$BUILD_ROOT_DIR/bin/;${OF_LIBS_ABS_PATH}/freetype/lib/osx"

        chmod -R 755 $BUILD_ROOT_DIR/lib/pkgconfig/

        echo "PATH :$PATH"
        export PKG_CONFIG="$BUILD_ROOT_DIR/bin/pkg-config"
		export PKG_CONFIG_PATH="$BUILD_ROOT_DIR/lib/pkgconfig"
        export FREETYPE_CFLAGS="-I${OF_LIBS_ABS_PATH}/freetype/include/freetype2"
        export FREETYPE_LIBS="-L${OF_LIBS_ABS_PATH}/freetype/lib/osx -lfreetype"
        export INCLUDE_ZLIB="-I$ROOT/zlib/build/"
		export INCLUDE_ZLIB_LIBS="-L$ROOT/zlib/build/ -lz"
        export png_REQUIRES="libpng16"
        export png_CFLAGS="-I$BUILD_ROOT_DIR/include/ -I$BUILD_ROOT_DIR/include/libpng16 $INCLUDE_ZLIB"
        export png_LIBS="-L$BUILD_ROOT_DIR/lib/ -lpng -L$BUILD_ROOT_DIR/lib/ -lpng16 $INCLUDE_ZLIB_LIBS"
        export FREETYPE_MIN_RELEASE=2.11.1
        export FREETYPE_MIN_VERSION=2.11.1
        export pixman_CFLAGS="-I$BUILD_ROOT_DIR/include/pixman-1"
        export pixman_LIBS="-L$BUILD_ROOT_DIR/lib/ -lpixman-1"
		export LDFLAGS="$ARCHS -m$SDK-version-min=$OSX_MIN_SDK_VER ${SYSROOT}"
		export CFLAGS="$ARCHS -m$SDK-version-min=$OSX_MIN_SDK_VER ${SYSROOT}" 
		export MACOSX_DEPLOYMENT_TARGET=$OSX_MIN_SDK_VER
		# export FREETYPE_MIN_VERSION=
	
		# $BUILD_ROOT_DIR/bin/pkg-config pixman-1 --libs
		# $BUILD_ROOT_DIR/bin/pkg-config libpng --libs
		# $BUILD_ROOT_DIR/bin/pkg-config freetype2 --libs
		# $BUILD_ROOT_DIR/bin/pkg-config zlib --libs

		echo "autogen"

		if [ ! -f configure ] ; then
			./autogen.sh
		fi
        
		echo "configure"
        ./configure \
        			PKG_CONFIG="$BUILD_ROOT_DIR/bin/pkg-config" \
					PKG_CONFIG_PATH="$BUILD_ROOT_DIR/lib/pkgconfig" \
					--prefix=$BUILD_ROOT_DIR \
					--disable-gtk-doc \
					--disable-full-testing \
					--disable-dependency-tracking \
					--disable-xlib \
					--disable-qt \
                    --disable-shared \
                    --disable-quartz-font \
                    --disable-quartz \
                    --disable-quartz-image
                            
        echo "make"
		make -j${PARALLEL_MAKE}
		make install

		rm ${OF_LIBS_ABS_PATH}/freetype/lib/osx/libfreetype.a
	else
		./configure PKG_CONFIG="$BUILD_ROOT_DIR/bin/pkg-config" \
					PKG_CONFIG_PATH="$BUILD_ROOT_DIR/lib/pkgconfig" \
					LDFLAGS="-arch i386 -arch x86_64" \
					CFLAGS="-Os -arch i386 -arch x86_64" \
					--prefix=$BUILD_ROOT_DIR \
					--disable-gtk-doc \
					--disable-gtk-doc-html \
					--disable-gtk-doc-pdf \
					--disable-full-testing \
					--disable-dependency-tracking \
					--disable-xlib \
					--disable-qt
		make -j${PARALLEL_MAKE}
		make install
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "vs" ] ; then
		#this copies all header files but we dont need all of them it seems
		#maybe alter the VS-Cairo build to separate necessary headers
		# make the path in the libs dir
		mkdir -p $1/include/cairo

		# copy the cairo headers
		cp -Rv src/*.h $1/include/cairo

		if [ $ARCH == 32 ] ; then
			# make the libs path
			mkdir -p $1/lib/$TYPE/Win32
			cp -v src/release/cairo-static.lib $1/lib/$TYPE/Win32/cairo-static.lib
		elif [ $ARCH == 64 ] ; then
			# make the libs path
			mkdir -p $1/lib/$TYPE/x64
			echo $PWD
			cp -v src/release/cairo-static.lib $1/lib/$TYPE/x64/cairo-static.lib
		fi

	elif [ "$TYPE" == "osx" -o "$TYPE" == "msys2" ] ; then
		# make the path in the libs dir
		mkdir -p $1/include/cairo

		# copy the cairo headers
		cp -Rv $BUILD_ROOT_DIR/include/cairo/* $1/include/cairo

		# make the libs path
		mkdir -p $1/lib/$TYPE

		if [ "$TYPE" == "osx" ] ; then
			cp -v $BUILD_ROOT_DIR/lib/libcairo-script-interpreter.a $1/lib/$TYPE/cairo-script-interpreter.a
		fi
		cp -v $BUILD_ROOT_DIR/lib/libcairo.a $1/lib/$TYPE/cairo.a
		cp -v $BUILD_ROOT_DIR/lib/libpixman-1.a $1/lib/$TYPE/pixman-1.a
		cp -v $BUILD_ROOT_DIR/lib/libpng.a $1/lib/$TYPE/png.a
	fi

	# copy license files
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v COPYING $1/license/
	cp -v COPYING-LGPL-2.1 $1/license/
	cp -v COPYING-MPL-1.1 $1/license/
}

# executed inside the lib src dir
function clean() {

	# manually clean dependencies
	apothecaryDependencies clean

	# cairo
	make clean
}
