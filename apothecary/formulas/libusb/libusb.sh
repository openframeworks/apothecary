#!/usr/bin/env bash
#
# libusb for ofxKinect needed for
# Visual Studio and OS X

FORMULA_TYPES=( "osx" "vs" )

# for osx 1.0.21 breaks libfreenect so this branch has 1.0.20 with changes to the XCode project to make it build static and not dynamic
#for vs 1.0.21 is good - but needs an unmerged PR / patch to fix iso transfers

GIT_URL=https://github.com/libusb/libusb
GIT_TAG=1.0.27
GIT_BRANCH_VS=master
VER=1.0.27

URL=https://github.com/libusb/libusb/releases/download/v${GIT_TAG}/libusb-${GIT_TAG}.tar.bz2

# download the source code and unpack it into LIB_NAME
function download() {

	git clone --branch ${GIT_BRANCH_VS} ${GIT_URL}

	# if [ "$TYPE" == "vs" ] ; then
  #       echo "Running: git clone --branch ${GIT_BRANCH_VS} ${GIT_URL}"
  #       git clone --branch ${GIT_BRANCH_VS} ${GIT_URL}
	# fi
  #
	# if [ "$TYPE" == "osx" ] ; then
  #       echo "Running: git clone --branch ${GIT_BRANCH_OSX} ${GIT_URL}"
  #       git clone --branch ${GIT_BRANCH_OSX} ${GIT_URL}
	# fi
	# . "$DOWNLOADER_SCRIPT"
	# downloader ${URL}
	# tar xjf libusb-${GIT_TAG}.tar.bz2
	# mv libusb-${GIT_TAG} libusb
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	cp -f $FORMULA_DIR/CMakeLists.txt .

	if [ "$TYPE" == "vs" ] ; then
		cp -f $FORMULA_DIR/config.h.in ./config.h.in
	else
		cp -f ./Xcode/config.h ./config.h
	fi
}

# executed inside the lib src dir
function build() {


	if [ "$TYPE" == "vs" ] ; then

	
		echo "building libusb $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${PLATFORM}"
	    cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.lib *.o
	    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=ON \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        -DLIBUSB_BUILD_TESTING=OFF \
            -DLIBUSB_BUILD_EXAMPLES=OFF \
            -DLIBUSB_INSTALL_TARGETS=ON \
            -DLIBUSB_BUILD_SHARED_LIBS=ON \
	        ${CMAKE_WIN_SDK} \
	        -DCMAKE_VERBOSE_MAKEFILE=ON \
	        -A "${PLATFORM}" \
	        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..

	fi

    if [ "$TYPE" == "osx" ] ; then
    	# ./autogen.sh
		# CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}" ./configure --disable-shared --enable-static
 		# make -j${PARALLEL_MAKE}

 		GENERATOR_NAME="Xcode"
	    mkdir -p "build_${TYPE}_${PLATFORM}"
	    cd "build_${TYPE}_${PLATFORM}"
	    rm -f CMakeCache.txt *.a *.o
	    DEFS="-DLIBRARY_SUFFIX=${PLATFORM} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=ON \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	    	-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -G Xcode \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DLIBUSB_BUILD_TESTING=OFF \
            -DLIBUSB_BUILD_EXAMPLES=OFF \
            -DLIBUSB_INSTALL_TARGETS=ON \
            -DLIBUSB_BUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DCMAKE_BUILD_TYPE=Release \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        -DCMAKE_VERBOSE_MAKEFILE=ON
	    cmake --build . --config Release --target install
	    cd ..
	fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -Rv libusb/libusb.h $1/include
	. "$SECURE_SCRIPT"
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libusb-1.0/" $1/
    	cp -f "build_${TYPE}_${PLATFORM}/Release/libusb-1.0.dll" $1/lib/$TYPE/$PLATFORM/libusb.dll
    	cp -f "build_${TYPE}_${PLATFORM}/Release/usb-1.0.lib" $1/lib/$TYPE/$PLATFORM/libusb.lib
		secure $1/lib/$TYPE/$PLATFORM/libusb.lib libusb
	fi
    if [ "$TYPE" == "osx" ] ; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libusb-1.0/" $1/ 
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libusb-1.0.a" $1/lib/$TYPE/$PLATFORM/libusb.a
		secure $1/lib/$TYPE/$PLATFORM/libusb.a libusb.pkl
	fi

	# copy license file
    if [ -d "$1/license" ]; then
        rm -r $1/license
    fi
    mkdir -p $1/license
    cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
		
	fi
    if [ "$TYPE" == "osx" ] ; then
        rm -f *.a
	fi

	if [ -d "build_${TYPE}_${PLATFORM}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${PLATFORM}	    
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "libusb" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
