#!/usr/bin/env /bash
#
# a low-level software library for pixel manipulation
# http://pixman.org/

# define the version
VER=0.32.4

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/pixman.git
GIT_TAG=pixman-$VER

FORMULA_TYPES=( "osx" "vs" )

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv --no-check-certificate http://cairographics.org/releases/pixman-$VER.tar.gz
	tar -xzf pixman-$VER.tar.gz
	mv pixman-$VER pixman
	rm pixman-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" != "vs" ] ; then
		if [ ! -f configure ] ; then
			./autogen.sh
		fi
	fi
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "osx" ] ; then
		# these flags are used to create a fat 32/64 binary with i386->libstdc++, x86_64->libc++
		# see https://gist.github.com/tgfrerer/8e2d973ed0cfdd514de6
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
                
		local FAT_LDFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot ${SDK_PATH}"

		./configure LDFLAGS="${FAT_LDFLAGS} " \
				CFLAGS="-O3 ${FAT_LDFLAGS}" \
				--prefix=$BUILD_ROOT_DIR \
				--disable-dependency-tracking \
				--disable-gtk \
				--disable-shared \
                --disable-mmx
		# only build & install lib, ignore demos/tests
		cd pixman
		make clean
		make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "vs" ] ; then
		sed -i s/-MD/-MT/ Makefile.win32.common
		cd pixman
		with_vs_env "make -f Makefile.win32 CFG=release MMX=off"
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		else
			PLATFORM="x64"
		fi
		mkdir -p $1/../cairo/lib/$TYPE/$PLATFORM/
		cp -v pixman/release/pixman-1.lib $1/../cairo/lib/$TYPE/$PLATFORM/
	else # osx
		# lib
		cd pixman
		make install

		# pkg-config info
		cd ../
		make install-pkgconfigDATA
	fi
}

# executed inside the lib src dir
function clean() {
	make uninstall
	make clean
}
