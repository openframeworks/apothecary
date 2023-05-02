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
		echo ""
	
		cp -Rv $FORMULA_DIR/ ./
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

	export OF_LIBS_ABS_PATH=$(realpath ${LIBS_DIR}/)
	if [ "$TYPE" == "vs" ] ; then

		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"    

        ROOT=$(realpath ${PWD}/..) 

		CAIRO_HAS_PNG_FUNCTIONS=1

		echoInfo "If any issue with LNK1104: cannot open file 'LIBCMT.lib make sure to install Spectre Mitigated VS C++Libs'"
		export ZLIB_PATH="$ROOT/zlib/build_${TYPE}_${ARCH}/Release/"
		export LIBPNG_PATH="$ROOT/libpng/build_${TYPE}_${ARCH}/Release"
		export PIXMAN_PATH="$ROOT/pixman/build_${TYPE}_${ARCH}/Release"		

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        DEFS="
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPIXMAN_ROOT=${PIXMAN_PATH} \
            -DPNG_ROOT=${LIBPNG_PATH} \
            -DZLIB_ROOT=${ZLIB_PATH} \
            -DPIXMAN_INCLUDE_DIR=${PIXMAN_PATH}/include/pixman-1 \
            -DPIXMAN_LIBRARIES=${PIXMAN_PATH}/lib/pixman-1_static.lib \
            -DZLIB_INCLUDE_DIR=${ZLIB_PATH}/include \
            -DZLIB_LIBRARY=${ZLIB_PATH}/zlib.lib \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_PATH}/include \
            -DPNG_LIBRARY=${LIBPNG_PATH}/lib/libpng16_static.lib \
            -DFREETYPE_ROOT={OF_LIBS_ABS_PATH}/freetype \
            -DFREETYPE_CFLAGS=-I${OF_LIBS_ABS_PATH}/freetype/include/freetype2 \
        	-DFREETYPE_LIBS=-L${OF_LIBS_ABS_PATH}/freetype/lib/$TYPE/$PLATFORM/libfreetype.lib \
        	-DBUILD_GTK_DOC=OFF -DBUILD_TESTS=OFF -DBUILD_DEPENDENCY_TRACKING=OFF -DBUILD_XLIB=OFF -DBUILD_QT=OFF -DBUILD_SHARED_LIBS=OFF -DBUILD_QUARTZ_FONT=OFF -DBUILD_QUARTZ=OFF -DBUILD_QUARTZ_IMAGE=OFF"
         
        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -D CMAKE_VERBOSE_MAKEFILE=ON \
		    -D BUILD_SHARED_LIBS=ON 
        cmake --build . --config Release --target install
 
        cd ..
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
		# make the path in the libs dir
		mkdir -p $1/include/cairo
		# copy the cairo headers
		
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/cairo $1/include/cairo"		
    	cp -v "build_${TYPE}_${ARCH}/Release/lib/cairo-static.lib" $1/lib/$TYPE/$PLATFORM/libcairo.lib 

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

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "cairo" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "cairo" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}