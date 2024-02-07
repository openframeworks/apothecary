#!/usr/bin/env /bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

# define the version
VER=1.3

# tools for git use
GIT_URL=https://github.com/madler/zlib/releases/download/v$VER/zlib-$VER.tar.gz

GIT_TAG=v$VER

FORMULA_TYPES=( "vs" "osx" "emscripten" "ios" "watchos" "catos" "xros" "tvos" )

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"

	downloader ${GIT_URL}
	tar -xf zlib-$VER.tar.gz
	mv zlib-$VER zlib
	rm -f zlib-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: #noop
	. "$DOWNLOADER_SCRIPT"
	downloader https://github.com/danoli3/zlib/raw/patch-1/CMakeLists.txt

}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)
	if [ "$TYPE" == "vs" ] ; then

		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoVerbose "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        cmake .. \
            -G "${GENERATOR_NAME}" \
            -A "${PLATFORM}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=ON \
		    -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
		    ${CMAKE_WIN_SDK} 
        cmake --build . --config Release --target install
        cd ..
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
		cmake .. \
			-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=OFF \
		    -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
		    -DSKIP_EXAMPLE=1 \
		    -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF 

		 cmake --build . --config Release --target install
		 cd ..
	elif [ "$TYPE" == "emscripten" ] ; then
		mkdir -p build_$TYPE
	    cd build_$TYPE
	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	-DCMAKE_BUILD_TYPE=Release \
	    	-DCMAKE_INSTALL_LIBDIR="build_${TYPE}" \
	    	-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
	    	-D BUILD_SHARED_LIBS=OFF \
		    -DSKIP_EXAMPLE=1 \
	    	-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include 
	  	cmake --build . --target install --config Release 
	    cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/include    
	    mkdir -p $1/lib/$TYPE
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a 
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include    
	    mkdir -p $1/lib/$TYPE
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/z.lib" $1/lib/$TYPE/$PLATFORM/zlib.lib  
	elif [ "$TYPE" == "emscripten" ] ; then
		mkdir -p $1/include
		mkdir -p $1/lib
		cp -Rv "build_${TYPE}/Release/include"* $1/include/
		mkdir -p $1/lib/$TYPE
		cp -v "build_${TYPE}/Release/lib/libz.a" $1/lib/$TYPE/zlib.a
	else
		make install
	fi

	# copy license file
	
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
    elif [ "$TYPE" == "emscripten" ] ; then
    	if [ -d "build_${TYPE}" ]; then
            rm -r build_${TYPE}     
        fi
	else
		make uninstall
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "zlib" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    echo "load file ${SAVE_FILE}"

    if loadsave ${TYPE} "zlib" ${ARCH} ${VER} "${SAVE_FILE}"; then
      echo "The entry exists and doesn't need to be rebuilt."
      return 0;
    else
      echo "The entry doesn't exist or needs to be rebuilt."
      return 1;
    fi
}
