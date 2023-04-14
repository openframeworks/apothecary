#!/usr/bin/env /bash
#
# a low-level software library for pixel manipulation
# http://pixman.org/

# define the version
VER=0.40.0
SHA1=d7baa6377b6f48e29db011c669788bb1268d08ad

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/pixman.git
GIT_TAG=pixman-$VER
URL=https://cairographics.org/releases



FORMULA_TYPES=( "osx" "vs" )

# download the source code and unpack it into LIB_NAME
function download() {
	
	wget -nv --no-check-certificate ${URL}/pixman-$VER.tar.gz
	tar -xzf pixman-$VER.tar.gz
	mv "pixman-$VER" pixman

	local CHECKSHA=$(shasum pixman-$VER.tar.gz | awk '{print $1}')
	if [ "$CHECKSHA" != "$SHA1" ] ; then
    	echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
    	exit
    else
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    fi


	rm pixman-$VER.tar.gz
}


# executed inside the lib src dir
function build() {
	mkdir -p pixman
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
		# sed -i s/-MD/-MT/ Makefile.win32.common
		# cd pixman
		# if [ $ARCH == 32 ] ; then
  #           PLATFORM="Win32"
  #       elif [ $ARCH == 64 ] ; then
  #           PLATFORM="x64"
  #       elif [ $ARCH == "ARM64" ] ; then
  #           PLATFORM="ARM64"
  #       elif [ $ARCH == "ARM" ] ; then
  #           PLATFORM="ARM"
  #       fi
		# with_vs_env "make -f Makefile.win32 CFG=release MMX=off"
		# make -j${PARALLEL_MAKE} VERBOSE=1

		if [ $ARCH == 32 ] ; then
            PLATFORM="Win32"
        elif [ $ARCH == 64 ] ; then
            PLATFORM="x64"
        elif [ $ARCH == "ARM64" ] ; then
            PLATFORM="ARM64"
        elif [ $ARCH == "ARM" ] ; then
            PLATFORM="ARM"
        fi

		mkdir -p build_$TYPE
		cd build_$TYPE

        cmake  .. \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="build_$TYPE" \
            -A ${PLATFORM} \
            -G "Visual Studio 16 2019"
            cmake --build . --config Release
            

        cd ..


	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
            PLATFORM="Win32"
        elif [ $ARCH == 64 ] ; then
            PLATFORM="x64"
        elif [ $ARCH == "ARM64" ] ; then
            PLATFORM="ARM64"
        elif [ $ARCH == "ARM" ] ; then
            PLATFORM="ARM"
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
