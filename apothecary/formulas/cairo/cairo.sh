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
FORMULA_DEPENDS=( "zlib" "libpng" "pixman" "freetype" )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
FORMULA_DEPENDS_MANUAL=1

VER=1.18.0
BUILD_ID=1
DEFINES=""

SHA1=fae6760ed0772681ddc60c603c9bb525ac74f000

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/cairo
GIT_TAG=$VER
URL=https://www.cairographics.org/releases/

GIT_LAB=https://gitlab.freedesktop.org/cairo/cairo/-/archive/${VER}/cairo-${VER}


# download the source code and unpack it into LIB_NAME
function download() {

	. "$DOWNLOADER_SCRIPT"

	downloader ${URL}/cairo-$VER.tar.xz
	tar -xJf cairo-$VER.tar.xz

	local CHECKSHA=$(shasum cairo-$VER.tar.xz | awk '{print $1}')
	rm cairo-$VER.tar.xz
	if [ "$CHECKSHA" != "$SHA1" ] ; then
    	echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
    	exit
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi

	mv "cairo-$VER" cairo

	# if [ "$TYPE" == "vs" ] ; then
	# 	downloader ${GIT_LAB}.zip
	# 	unzip -qq "cairo-$VER.zip"
    #     rm -f "cairo-$VER.zip"
	# 	mv cairo-$VER cairo
	# else
	# 	downloader ${GIT_LAB}.tar.bz2
	# 	tar -xf cairo-$VER.tar.bz2
	# 	mv cairo-$VER cairo
	# 	rm cairo-$VER.tar.bz2
	# fi
	#downloader https://cairographics.org/releases/cairo-$VER.tar.xz
	
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
	
		cp -RvT $FORMULA_DIR/ ./
	else
		# generate the configure script if it's not there
		
		# Build and copy all dependencies in preparation
		# apothecaryDepend download pkg-config
		# apothecaryDepend prepare pkg-config
		# apothecaryDepend build pkg-config
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

		cp -Rv $FORMULA_DIR/ ./
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

        LIBS_ROOT=$(realpath $LIBS_DIR)

		CAIRO_HAS_PNG_FUNCTIONS=1

		echoInfo "If any issue with LNK1104: cannot open file 'LIBCMT.lib make sure to install Spectre Mitigated VS C++Libs'"
		
		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

		LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib"

		PIXMAN_ROOT="$LIBS_ROOT/pixman/"
		PIXMAN_INCLUDE_DIR="$LIBS_ROOT/pixman/include"
		PIXMAN_LIBRARY="$LIBS_ROOT/pixman/lib/$TYPE/$PLATFORM/libpixman-1.lib"

		FREETYPE_ROOT="$LIBS_ROOT/freetype/"
		FREETYPE_INCLUDE_DIR="$LIBS_ROOT/freetype/include"
		FREETYPE_LIBRARY="$LIBS_ROOT/freetype/lib/$TYPE/$PLATFORM/freetype.lib"
		FREETYPE_LIBRARIES="$LIBS_ROOT/freetype/lib/$TYPE/$PLATFORM/freetype.lib"

		LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"
        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/brotlicommon.lib"
        LIBBROTLI_ENC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/brotlienc.lib"
        LIBBROTLI_DEC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/brotlidec.lib"

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.lib
        DEFS="
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPIXMAN_ROOT=${PIXMAN_ROOT} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DFREETYPE_ROOT=${FREETYPE_ROOT} \
            -DPIXMAN_INCLUDE_DIR=${PIXMAN_INCLUDE_DIR} \
            -DPIXMAN_LIBRARY=${PIXMAN_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DFREETYPE_LIBRARY=${FREETYPE_LIBRARY} \
            -DFREETYPE_INCLUDE_DIR=${FREETYPE_INCLUDE_DIR} \
            -DFREETYPE_INCLUDE_DIRS=${FREETYPE_INCLUDE_DIR} \
            -DFREETYPE_INCLUDE_DIR_ft2build=${FREETYPE_INCLUDE_DIR} \
            -DFREETYPE_INCLUDE_DIR_freetype2="${FREETYPE_INCLUDE_DIR}/freetype" \
            -DFREETYPE_CFLAGS="-I${FREETYPE_INCLUDE_DIR}" \
        	-DFREETYPE_LIBS=${FREETYPE_LIBRARY} \
        	-DBUILD_GTK_DOC=OFF -DBUILD_TESTS=OFF -DBUILD_DEPENDENCY_TRACKING=OFF -DBUILD_XLIB=OFF -DBUILD_QT=OFF -DBUILD_QUARTZ_FONT=OFF -DBUILD_QUARTZ=OFF -DBUILD_QUARTZ_IMAGE=OFF"
        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DBROTLI_ROOT=${LIBBROTLI_ROOT} \
            -DBROTLIDEC_INCLUDE_DIRS="${LIBBROTLI_INCLUDE_DIR}" \
            -DBROTLI_INCLUDE_DIR="${LIBBROTLI_INCLUDE_DIR}" \
            -DBROTLIDEC_LIBRARIES="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB}" \
            -DCMAKE_INCLUDE_PATH="${LIBBROTLI_INCLUDE_DIR};${FREETYPE_INCLUDE_DIR};${LIBPNG_INCLUDE_DIR};${ZLIB_INCLUDE_DIR};${PIXMAN_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB};${FREETYPE_LIBRARY};${LIBPNG_LIBRARY};${ZLIB_LIBRARY};${PIXMAN_LIBRARY}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -D CMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D CAIRO_WIN32_STATIC_BUILD=ON \
		    -DNO_FONTCONFIG=OFF \
		    -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
		    -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
		    -DENABLE_VISIBILITY=OFF \
		    ${CMAKE_WIN_SDK}
        cmake --build . --config Release --target install
        cd ..
	elif [ "$TYPE" == "osx" ] ; then

	    LIBS_ROOT=$(realpath $LIBS_DIR)


		CAIRO_HAS_PNG_FUNCTIONS=1


		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

		LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"	

		PIXMAN_ROOT="$LIBS_ROOT/pixman/"
		PIXMAN_INCLUDE_DIR="$LIBS_ROOT/pixman/include"
		PIXMAN_LIBRARY="$LIBS_ROOT/pixman/lib/$TYPE/$PLATFORM/libpixman-1.a"

		FREETYPE_ROOT="$LIBS_ROOT/freetype/"
		FREETYPE_INCLUDE_DIR="$LIBS_ROOT/freetype/include"
		FREETYPE_LIBRARY="$LIBS_ROOT/freetype/lib/$TYPE/$PLATFORM/libfreetype.a"

		LIBBROTLI_ROOT="$LIBS_ROOT/brotli/"
        LIBBROTLI_INCLUDE_DIR="$LIBS_ROOT/brotli/include"
        LIBBROTLI_LIBRARY="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlicommon.a"
        LIBBROTLI_ENC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlienc.a"
        LIBBROTLI_DEC_LIB="$LIBS_ROOT/brotli/lib/$TYPE/$PLATFORM/libbrotlidec.a"

	    mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o 
        DEFS="
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPIXMAN_ROOT=${PIXMAN_ROOT} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DFREETYPE_ROOT=${FREETYPE_ROOT} \
            -DPIXMAN_INCLUDE_DIR=${PIXMAN_INCLUDE_DIR} \
            -DPIXMAN_LIBRARY=${PIXMAN_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DFREETYPE_LIBRARY=${FREETYPE_LIBRARY} \
            -DFREETYPE_INCLUDE_DIR=${FREETYPE_INCLUDE_DIR} \
            -DFREETYPE_INCLUDE_DIRS=${FREETYPE_INCLUDE_DIR} \
            -DFREETYPE_CFLAGS=-I${FREETYPE_INCLUDE_DIR}/freetype \
        	-DFREETYPE_LIBS=${FREETYPE_LIBRARY} \
        	-DBUILD_GTK_DOC=OFF -DNO_BUILD_TESTS=ON -DNO_DEPENDENCY_TRACKING=ON -DBUILD_XLIB=OFF -DNO_QT=ON -DBUILD_SHARED_LIBS=OFF -DNO_QUARTZ_FONT=OFF -DNO_QUARTZ=OFF -DNO_QUARTZ_IMAGE=OFF"

        cmake .. ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DBROTLIDEC_INCLUDE_DIRS="${LIBBROTLI_INCLUDE_DIR}" \
            -DBROTLI_INCLUDE_DIR="${LIBBROTLI_INCLUDE_DIR}" \
            -DBROTLIDEC_LIBRARIES="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB}" \
            -DCMAKE_INCLUDE_PATH="${LIBBROTLI_INCLUDE_DIR};${FREETYPE_INCLUDE_DIR};${LIBPNG_INCLUDE_DIR};${ZLIB_INCLUDE_DIR};${PIXMAN_INCLUDE_DIR}" \
            -DCMAKE_LIBRARY_PATH="${LIBBROTLI_LIBRARY};${LIBBROTLI_DEC_LIB};${LIBBROTLI_ENC_LIB};${FREETYPE_LIBRARY};${LIBPNG_LIBRARY};${ZLIB_LIBRARY};${PIXMAN_LIBRARY}" \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_STATIC_LIBS=ON \
            -DENABLE_VISIBILITY=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DNO_FONTCONFIG=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -D CMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} 
        cmake --build . --config Release
        cmake --install . --config Release
	    cd ..
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
	mkdir -p $1/include
	. "$SECURE_SCRIPT"
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include/cairo	
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/
    	cp -v "build_${TYPE}_${ARCH}/Release/lib/cairo-static.lib" $1/lib/$TYPE/$PLATFORM/libcairo.lib 
		secure $1/lib/$TYPE/$PLATFORM/libcairo.lib cairo.pkl
	elif [ "$TYPE" == "osx" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcairo-static.a" $1/lib/$TYPE/$PLATFORM/libcairo.a
		secure $1/lib/$TYPE/$PLATFORM/libcairo.a cairo.pkl
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/
	fi
	# copy license files
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
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


function load() {
     . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "cairo" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}