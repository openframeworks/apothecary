#!/usr/bin/env /bash
#
# a low-level software library for pixel manipulation
# http://pixman.org/

FORMULA_TYPES=( "osx" "vs" )
FORMULA_DEPENDS=( )

# define the version
VER=0.43.4
SHA1=d7baa6377b6f48e29db011c669788bb1268d08ad
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/pixman.git
GIT_TAG=pixman-$VER
URL=https://cairographics.org/releases

# download the source code and unpack it into LIB_NAME
function download() {

	. "$DOWNLOADER_SCRIPT"

	downloader ${URL}/pixman-$VER.tar.gz
	tar -xzf pixman-$VER.tar.gz
	mv "pixman-$VER" pixman

	local CHECKSHA=$(shasum pixman-$VER.tar.gz | awk '{print $1}')
	# if [ "$CHECKSHA" != "$SHA1" ] ; then
    # 	echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
    # 	exit
    # else
    #     echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
    # fi
	rm pixman-$VER.tar.gz

	echo "copying cmake files to dir"
	cp -v $FORMULA_DIR/_depends/pixman/CMakeLists.txt pixman/CMakeLists.txt
	cp -v $FORMULA_DIR/_depends/pixman/pixman/CMakeLists.txt pixman/pixman/CMakeLists.txt
	mkdir -p pixman/cmake
	cp -vr $FORMULA_DIR/_depends/pixman/cmake/* pixman/cmake/
}


# executed inside the lib src dir
function build() {
	mkdir -p pixman
	if [ "$TYPE" == "osx" ] ; then
		echo "building $TYPE | $PLATFORM"
        echo "--------------------"
      
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
         rm -f CMakeCache.txt *.a *.o 
        cmake  .. \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_CONFIG_NAME=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=lib \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=bin \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DBUILD_STATIC=ON \
            -DBUILD_SHARED=OFF 
            # -G Xcode 
        cmake --build .  --config Release --target install 
        cd ..
	elif [ "$TYPE" == "vs" ] ; then
		# sed -i s/-MD/-MT/ Makefile.win32.common

        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
         rm -f CMakeCache.txt *.a *.o *.lib
        cmake  .. \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
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
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -D CMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            ${CMAKE_WIN_SDK} \
		    -DBUILD_STATIC=ON \
            -DBUILD_SHARED=OFF \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
            
            cmake --build . --config Release --target install     

        cd ..

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    . "$SECURE_SCRIPT"
    mkdir -p $1/include
    if [ -d "$1/license" ]; then
            rm -rf $1/license
    fi
    mkdir -p $1/license
	if [ "$TYPE" == "vs" ] ; then		

		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/pixman-1_static.lib" $1/lib/$TYPE/$PLATFORM/libpixman-1.lib
    	cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/pixman-1/"* $1/include
        secure $1/lib/$TYPE/$PLATFORM/libpixman-1.lib pixman.pkl
	else # osx
		# lib
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/pixman/lib/libpixman-1.a" $1/lib/$TYPE/$PLATFORM/libpixman-1.a
    	cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/pixman-1/"* $1/include
        secure $1/lib/$TYPE/$PLATFORM/libpixman-1.a pixman.pkl
	fi
    cp -v COPYING $1/license/LICENSE

}

# executed inside the lib src dir
function clean() {
	make uninstall
	make clean
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "pixman" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
