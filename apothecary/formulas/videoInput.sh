#!/usr/bin/env bash
#
# videoInput
# A video capture library for windows
# https://github.com/ofTheo/videoInput
#
# Visual Studio & Code Blocks projects are provided

FORMULA_TYPES=( "vs" "msys2" )
FORMULA_DEPENDS=(  ) 

# define the version
VER=master
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/ofTheo/videoInput.git
GIT_BRANCH=$VER

CMAKE_LIST=https://raw.githubusercontent.com/danoli3/videoInput/master/videoInputSrcAndDemos/libs/videoInput/CMakeLists.txt

# download the source code and unpack it into LIB_NAME
function download() {
    echo "Running: git clone --branch ${GIT_BRANCH} ${GIT_URL}"
	git clone --branch ${GIT_BRANCH} ${GIT_URL}
	
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	. "$DOWNLOADER_SCRIPT"
	downloader ${CMAKE_LIST} 

	mv -f CMakeLists.txt "videoInputSrcAndDemos/libs/videoInput/CMakeLists.txt"
}

# executed inside the lib src dir
function build() {

	cd videoInputSrcAndDemos

	if [ "$TYPE" == "vs" ] ; then
		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoVerbose "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        DEFS="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            ${CMAKE_WIN_SDK} "
         
        cmake ../libs/videoInput ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
            
        cmake --build . --config Release

        cmake ../libs/videoInput ${DEFS} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} " \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
            
        cmake --build . --config Debug
 
        cd ..

	elif [ "$TYPE" == "msys2" ] ; then
		mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"
        
        cmake ../libs/videoInput ${DEFS} \
            -G "MSYS Makefiles" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -Iinclude ${FLAG_RELEASE}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_SYSTEM_NAME=MSYS \
            -DCMAKE_SYSTEM_PROCESSOR=${ARCH}
        
        cmake --build . --config Release 
        cd ..
	fi

    # List all files in the build directory
    echo "Listing all files in build directory:"
    ls -a "build_${TYPE}_${ARCH}"

    # List all files in the Release directory if it exists
    if [ -d "build_${TYPE}_${ARCH}/Release" ]; then
        echo "Listing all files in Release directory:"
        ls -a "build_${TYPE}_${ARCH}/Release"
    fi

    cd ..
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -Rv videoInputSrcAndDemos/libs/videoInput/videoInput.h $1/include

	if [ "$TYPE" == "vs" ] ; then				
	    mkdir -p $1/lib/$TYPE
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "videoInputSrcAndDemos/build_${TYPE}_${ARCH}/Release/videoInput.lib" $1/lib/$TYPE/$PLATFORM/videoInput.lib 
        cp -v "videoInputSrcAndDemos/build_${TYPE}_${ARCH}/Debug/videoInput.lib" $1/lib/$TYPE/$PLATFORM/videoInputD.lib  
	else
		mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "videoInputSrcAndDemos/build_${TYPE}_${ARCH}/libvideoInput.a" $1/lib/$TYPE/$PLATFORM/videoInput.a

	fi

	echoWarning "TODO: License Copy"
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
        if [ -d "videoInputSrcAndDemos/build_${TYPE}_${ARCH}" ]; then
            rm -r videoInputSrcAndDemos/build_${TYPE}_${ARCH}     
        fi
	elif [ "$TYPE" == "msys2"  ] ; then
		if [ -d "videoInputSrcAndDemos/build_${TYPE}_${ARCH}" ]; then
            rm -r videoInputSrcAndDemos/build_${TYPE}_${ARCH}     
        fi
	fi
}
