#!/usr/bin/env bash
#
# the official PNG reference library
# http://libpng.org/pub/png/libpng.html

# define the version
MAJOR_VER=16
VER=1.6.25

# tools for git use
GIT_URL=http://git.code.sf.net/p/libpng/code
GIT_TAG=v$VER

FORMULA_TYPES=( "osx" "vs" )

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv --no-check-certificate http://prdownloads.sourceforge.net/libpng/libpng-$VER.tar.gz?download -O libpng-$VER.tar.gz
	tar -xf libpng-$VER.tar.gz
	mv libpng-$VER libpng
	rm libpng-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# generate the configure script if it's not there
	if [ ! -f configure ] ; then
		./autogen.sh
	fi
	if [ "$TYPE" == "vs" ] ; then
		#need to download this for the vs solution to build
		if [ ! -e ../zlib ] ; then
			echoError "libpng needs zlib, please update that formula first"
		fi
		#CURRENTPATH=`pwd`
		cp -vr $FORMULA_DIR/vs2015 projects/
	fi
}

# executed inside the lib src dir
function build() {

	if [ "$TYPE" == "osx" ] ; then
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        
		# these flags are used to create a fat arm/64 binary with libc++
		# see https://gist.github.com/tgfrerer/8e2d973ed0cfdd514de6
		local FAT_LDFLAGS="-arch arm64 -arch x86_64 -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot ${SDK_PATH}"

		./configure LDFLAGS="${FAT_LDFLAGS} " \
				CFLAGS="-O3 ${FAT_LDFLAGS}" \
				--prefix=$BUILD_ROOT_DIR \
				--disable-dependency-tracking \
                --disable-arm-neon \
                --disable-shared
		make clean
		make
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd projects/vs2015

		vs-upgrade libpng.sln

		if [ $ARCH == 32 ] ; then
			vs-build libpng.sln Build "LIB Release|x86"
		elif [ $ARCH == 64 ] ; then
			vs-build libpng.sln Build "LIB Release|x64"
		fi
	fi



}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "vs" ] ; then
		if [ "$ARCH" == 32 ]; then
			mkdir -p $1/../cairo/lib/vs/Win32/
			cp ../libpng/projects/vs2015/Win32_LIB_Release/libpng.lib $1/../cairo/lib/vs/Win32/
		else
			mkdir -p $1/../cairo/lib/vs/x64/
			cp ../libpng/projects/vs2015/x64/LIB\ Release/libpng.lib $1/../cairo/lib/vs/x64/
		fi
	else
		make install
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			echo "to do clean vs build"
		fi
	else
		make uninstall
		make clean
	fi
}
