#!/usr/bin/env bash
#
# videoInput
# A video capture library for windows
# https://github.com/ofTheo/videoInput
#
# Visual Studio & Code Blocks projects are provided

FORMULA_TYPES=( "vs" "msys2" )

# define the version
VER=master

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
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
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
            -D CMAKE_VERBOSE_MAKEFILE=ON 
            
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
            -D CMAKE_VERBOSE_MAKEFILE=ON 
            
        cmake --build . --config Debug
 
        cd ..

	elif [ "$TYPE" == "msys2" ] ; then
		cd msys2
		make
	fi
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
		cp -v compiledLib/msys2/libvideoinput.a $1/lib/$TYPE/
	fi

	echoWarning "TODO: License Copy"
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		cd videoInputSrcAndDemos/VS-videoInputcompileAsLib
		vs-clean "videoInput.sln"
	elif [ "$TYPE" == "msys2" ] ; then
		cd videoInputSrcAndDemos/msys2
		make clean
	fi
}
