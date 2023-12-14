#!/usr/bin/env bash
#
# libusb for ofxKinect needed for
# Visual Studio and OS X

FORMULA_TYPES=( "osx" "vs" )

# for osx 1.0.21 breaks libfreenect so this branch has 1.0.20 with changes to the XCode project to make it build static and not dynamic
#for vs 1.0.21 is good - but needs an unmerged PR / patch to fix iso transfers

GIT_URL=https://github.com/libusb/libusb
GIT_TAG=1.0.26
GIT_BRANCH_VS=master

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
}

# executed inside the lib src dir
function build() {


	if [ "$TYPE" == "vs" ] ; then

	
		echo "building libusb $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${ARCH}"
	    cd "build_${TYPE}_${ARCH}"
	    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        ${CMAKE_WIN_SDK} \
	        -DCMAKE_VERBOSE_MAKEFILE=ON \
	        -A "${PLATFORM}" \
	        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..

	fi

    if [ "$TYPE" == "osx" ] ; then
    	./autogen.sh
		CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}" ./configure --disable-shared --enable-static
 		make -j${PARALLEL_MAKE}
	fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -Rv libusb/libusb.h $1/include

	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
    	cp -f "build_${TYPE}_${ARCH}/Release/lib/libusb-1.0.lib" $1/lib/$TYPE/$PLATFORM/libusb-1.0.lib

	fi

    if [ "$TYPE" == "osx" ] ; then
        mkdir -p $1/lib/$TYPE
        cp -v libusb/.libs/libusb-1.0.a $1/lib/$TYPE/usb-1.0.0.a
	fi

	echoWarning "TODO: License Copy"
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	fi

    if [ "$TYPE" == "osx" ] ; then
        cd Xcode
    	xcodebuild -configuration Release -target libusb -project libusb.xcodeproj/ clean
	fi
}
