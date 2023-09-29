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

	. "$DOWNLOADER_SCRIPT"

	downloader ${URL}/pixman-$VER.tar.gz
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

	echo "copying cmake files to dir"
	cp -v $FORMULA_DIR/_depends/pixman/CMakeLists.txt pixman/CMakeLists.txt
	cp -v $FORMULA_DIR/_depends/pixman/pixman/CMakeLists.txt pixman/pixman/CMakeLists.txt
	mkdir -p pixman/cmake
	cp -vr $FORMULA_DIR/_depends/pixman/cmake/ pixman/
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

        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"

        cmake  .. \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_PREFIX=Release \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin \
            -D CMAKE_VERBOSE_MAKEFILE=OFF \
            ${CMAKE_WIN_SDK} \
		    -DBUILD_SHARED_LIBS=ON \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
            
            cmake --build . --config Release --target install     

        cd ..

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	if [ "$TYPE" == "vs" ] ; then		

		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/lib/pixman-1_static.lib" $1/lib/$TYPE/$PLATFORM/libpixman-1.lib
    	cp -RvT "build_${TYPE}_${ARCH}/Release/include/pixman-1" $1/include

    	# copy license file
		if [ -d "$1/license" ]; then
	        rm -rf $1/license
	    fi
		mkdir -p $1/license
		cp -v COPYING $1/license/LICENSE

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

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "pixman" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    echo "load file ${SAVE_FILE}"

    if loadsave ${TYPE} "pixman" ${ARCH} ${VER} "${SAVE_FILE}"; then
      echo "The entry exists and doesn't need to be rebuilt."
      return 0;
    else
      echo "The entry doesn't exist or needs to be rebuilt."
      return 1;
    fi
}
