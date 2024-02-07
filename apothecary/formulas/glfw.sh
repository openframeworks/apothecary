#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" )

# define the version by branch  
# VER=2018-cmake-fix
# tools for git use
# GIT_URL=https://github.com/ofTheo/glfw/
GIT_URL=https://github.com/glfw/glfw/
# VER=master
VER=3.3.9
GIT_BRANCH=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	 echo "Running: git clone --branch ${GIT_BRANCH} ${GIT_URL}"
     git clone --branch ${GIT_BRANCH} ${GIT_URL} --depth 1
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
}

# executed inside the lib src dir
function build() {
	
	LIBS_ROOT=$(realpath $LIBS_DIR)

	if [ "$TYPE" == "vs" ] ; then
		echo "building glfw $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.o *.lib
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        DEFS="
        	-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
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
        	-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DGLFW_BUILD_EXAMPLES=OFF \
            -DGLFW_BUILD_TESTS=OFF \
            -DGLFW_BUILD_DOCS=OFF \
            -DGLFW_VULKAN_STATIC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"

        cmake --build . --config Release --target install

        cd ..
	elif [ "$TYPE" == "osx" ] ; then
		if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            EXTRA_CONFIG="-DGLFW_USE_EGL=1 -DGLFW_CLIENT_LIBRARY=glesv2 -DCMAKE_LIBRARY_PATH=$SYSROOT/usr/lib -DCMAKE_INCLUDE_PATH=$SYSROOT/usr/include"
        else
            EXTRA_CONFIG=" "
        fi
		# *nix build system

		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.o *.a

		# OS X needs both arches specified to be universal
		# for some reason it doesn't build if passed through EXTRA_CONFIG so have do break it up into a separate cmake call
		cmake .. -DGLFW_BUILD_DOCS=OFF \
				-DGLFW_BUILD_TESTS=OFF \
				-DGLFW_BUILD_EXAMPLES=OFF \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
				-DENABLE_BITCODE=OFF \
				-DCMAKE_CXX_FLAGS="-fPIC ${CFLAGS}" \
				-DCMAKE_C_FLAGS="-fPIC ${CFLAGS}" \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_BUILD_TYPE=Release \
			    -DCMAKE_C_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
			    -DCMAKE_CXX_EXTENSIONS=OFF \
			    -DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include \
				-DCMAKE_INSTALL_LIBDIR=lib \
				$EXTRA_CONFIG
		cmake --build . --config Release --target install
		cd ..


	else
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            EXTRA_CONFIG="-DGLFW_USE_EGL=1 -DGLFW_CLIENT_LIBRARY=glesv2 -DCMAKE_LIBRARY_PATH=$SYSROOT/usr/lib -DCMAKE_INCLUDE_PATH=$SYSROOT/usr/include"
        else
            EXTRA_CONFIG=" "
        fi
		# *nix build system

		mkdir -p build
		cd build

		# OS X needs both arches specified to be universal
		# for some reason it doesn't build if passed through EXTRA_CONFIG so have do break it up into a separate cmake call
		cmake .. -DGLFW_BUILD_DOCS=OFF \
				-DGLFW_BUILD_TESTS=OFF \
				-DGLFW_BUILD_EXAMPLES=OFF \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_BUILD_TYPE=Release \
			    -DCMAKE_C_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
			    -DCMAKE_CXX_EXTENSIONS=OFF \
				$EXTRA_CONFIG
		

 		make clean
 		make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/GLFW
	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${ARCH}/Release/lib/glfw3.lib" $1/lib/$TYPE/$PLATFORM/glfw3.lib   
	elif [ "$TYPE" == "osx" ]; then
		# Standard *nix style copy.
		# copy headers
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libglfw3.a" $1/lib/$TYPE/$PLATFORM/libglfw3.a
	fi

	# copy license file
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.md $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            # Delete the folder and its contents
            rm -r build_${TYPE}_${ARCH}     
        fi
    elif [ "$TYPE" == "osx" ] ; then
		rm -f *.a
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            # Delete the folder and its contents
            rm -r build_${TYPE}_${PLATFORM}     
        fi
	else
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "glfw" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "glfw" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
