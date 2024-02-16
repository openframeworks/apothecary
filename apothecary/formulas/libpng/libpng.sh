#!/usr/bin/env bash
#
# the official PNG reference library
# http://libpng.org/pub/png/libpng.html

# define the version
MAJOR_VER=16
VER=1.6.42

# tools for git use
GIT_URL=http://git.code.sf.net/p/libpng/code
GIT_TAG=v$VER
#URL=https://github.com/glennrp/libpng/archive/refs/tags/v1.6.40 # Glenn Randers-Pehrson 
URL=https://github.com/pnggroup/libpng/archive/refs/tags/v${VER}
SHA=
WINDOWS_URL=https://github.com/pnggroup/libpng/archive/refs/tags/v${VER}

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" )

FORMULA_DEPENDS=( "zlib" ) 


# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"

	if [ "$TYPE" == "vs" ] ; then
		downloader "${URL}.zip"
		unzip -q "v${VER}.zip"
		mv "libpng-${VER}" libpng
		rm "v${VER}.zip"
	else 
		echo https://github.com/pnggroup/libpng/archive/refs/tags/v1.6.42.tar.gz
		downloader "${URL}.tar.gz"
		tar -xf "v${VER}.tar.gz"
		mv "libpng-${VER}" libpng
		rm "v${VER}.tar.gz"
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {

	

	# generate the configure script if it's not there
	if [ ! -f configure ] ; then
		./autogen.sh
	fi

	apothecaryDepend download zlib
	apothecaryDepend prepare zlib
	apothecaryDepend build zlib
	apothecaryDepend copy zlib

	if [ "$TYPE" == "vs" ] ; then
		#need to download this for the vs solution to build
		if [ ! -e ../zlib ] ; then
			echoError "libpng needs zlib, please update that formula first"
		fi
	fi

	cp -Rv $FORMULA_DIR/ ./

	
}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)

	DEFS="
		    -DCMAKE_C_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD=17 \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
		    -DPNG_BUILD_ZLIB=OFF \
		    -DPNG_TESTS=OFF \
		    -DPNG_SHARED=OFF \
		    -DPNG_STATIC=ON \
		    -DBUILD_SHARED_LIBS=OFF \
		    -DPNG_HARDWARE_OPTIMIZATIONS=ON \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include"
	
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"		

		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DZLIB_ROOT=${ZLIB_ROOT} \
		    	-DZLIB_LIBRARY=${ZLIB_LIBRARY} \
		    	-DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
		    	-DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_BUILD_TYPE=Release \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..	
	elif [ "$TYPE" == "vs" ] ; then
		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	  	echoVerbose "--------------------"
	  	GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 

	  	mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"
		rm -f CMakeCache.txt *.lib *.o

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

  		env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
  		env CFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
		cmake .. ${DEFS} \
			-B . \
			-DZLIB_ROOT=${ZLIB_ROOT} \
	    	-DZLIB_LIBRARY=${ZLIB_LIBRARY} \
	    	-DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
	    	-DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
	    	-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_BUILD_TYPE=Release \
		    -A "${PLATFORM}" \
		    -G "${GENERATOR_NAME}" \
		    ${CMAKE_WIN_SDK} \
		    -UCMAKE_CXX_FLAGS \
		    -UCMAKE_C_FLAGS \
		    -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	      	-DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
		    -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=ON

		cmake --build . --config Release  --target install

		cd ..	

	elif [ "$TYPE" == "android" ] ; then

		source $APOTHECARY_DIR/android_configure.sh $ABI cmake

		mkdir -p "build_${TYPE}_${ABI}"
		cd "build_${TYPE}_${ABI}"
		rm -f CMakeCache.txt *.a *.o

		export CFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -std=c17"
		export CXXFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -std=c++17"
		export LDFLAGS="$LDFLAGS $EXTRA_LINK_FLAGS -shared"


		ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$ABI/zlib.a"	

			cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_COMPILER=${CC} \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_BUILD_TYPE=Release \
	     	 	-D CMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
	     	 	-D CMAKE_C_COMPILER_RANLIB=${RANLIB} \
	     	 	-D CMAKE_CXX_COMPILER_AR=${AR} \
	     	 	-D CMAKE_C_COMPILER_AR=${AR} \
	     	 	-D CMAKE_C_COMPILER=${CC} \
	     	 	-D CMAKE_CXX_COMPILER=${CXX} \
	     	 	-D CMAKE_C_FLAGS=${CFLAGS} \
	     	 	-D CMAKE_CXX_FLAGS=${CXXFLAGS} \
	        	-D ANDROID_ABI=${ABI} \
	        	-D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
	        	-D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
	        	-D CMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
	        	-D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
	        	-D ANDROID_TOOLCHAIN=clang \
	        	-DZLIB_ROOT=${ZLIB_ROOT} \
				-DZLIB_LIBRARY=${ZLIB_LIBRARY} \
				-DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
				-DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..
	elif [ "$TYPE" == "emscripten" ]; then
		mkdir -p build_$TYPE
	    cd build_$TYPE
	    rm -f CMakeCache.txt *.a *.o *.wasm

	    ZLIB_ROOT="$LIBS_ROOT/zlib/"
		ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
		ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/zlib.wasm"

	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	${DEFS} \
	    	-DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
	    	-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++17 -Wno-implicit-function-declaration -frtti -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c17 -Wno-implicit-function-declaration -frtti -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DZLIB_ROOT=${ZLIB_ROOT} \
			-DZLIB_LIBRARY=${ZLIB_LIBRARY} \
			-DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
			-DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
			-DCMAKE_BUILD_TYPE=Release \
			-DBUILD_SHARED_LIBS=ON \
			-DPNG_EXECUTABLES=OFF \
			-DPNG_BUILD_ZLIB=OFF 
	    cmake --build . --target install --config Release
	    cd ..
		
	fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	mkdir -p $1/include
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		mkdir -p $1/include
		cp -v "build_${TYPE}_${ARCH}/Release/lib/libpng16_static.lib" $1/lib/$TYPE/$PLATFORM/libpng.lib
		cp -RT "build_${TYPE}_${ARCH}/Release/include/" $1/include
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		mkdir -p $1/include
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libpng16.a" $1/lib/$TYPE/$PLATFORM/libpng.a
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
	elif [ "$TYPE" == "android" ] ; then
		mkdir -p $1/lib/$TYPE/$ABI/
		mkdir -p $1/include
		cp -v "build_${TYPE}_${ABI}/Release/lib/libpng16_static.lib" $1/lib/$TYPE/$ABI/libpng.a
		cp -RT "build_${TYPE}_${ABI}/Release/include/" $1/include
	elif [ "$TYPE" == "emscripten" ] ; then
		mkdir -p $1/lib/$TYPE/
		mkdir -p $1/include
		cp -v "build_${TYPE}/libpng_wasm.wasm" $1/lib/$TYPE/libpng.wasm
		cp -R "build_${TYPE}/Release/include/" $1/include
	else
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/libpng16.a" $1/lib/$TYPE/$PLATFORM/libpng16.a
		cp -v "build_${TYPE}_${PLATFORM}/Release/libpng.a" $1/lib/$TYPE/$PLATFORM/libpng.a
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include	
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
    if [ -d "build_${TYPE}_${ARCH}" ]; then
        rm -r build_${TYPE}_${ARCH}     
    fi
	elif [ "$TYPE" == "android" ] ; then
		if [ -d "build_${TYPE}_${ABI}" ]; then
			rm -r build_${TYPE}_${ABI}     
		fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
	        rm -r build_${TYPE}_${PLATFORM}     
	  fi
	else
		make uninstall
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "libpng" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "libpng" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
