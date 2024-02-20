#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system


FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" )

# define the version by sha
VER=0.9.7

# tools for git use
GIT_URL=https://github.com/uriparser/uriparser
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	git clone $GIT_URL uriparser
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	echo "prepare"
	rm -f ./CMakeLists.txt
   cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt
}

# executed inside the lib src dir
function build() {
	echo "uriparser build" 
	LIBS_ROOT=$(realpath $LIBS_DIR)
	DEFS=" 
			-DCMAKE_C_STANDARD=17 \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_STANDARD_REQUIRED=ON \
      -DCMAKE_CXX_EXTENSIONS=OFF \
			-DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=OFF \
 			-DURIPARSER_BUILD_WCHAR_T=ON \
 			-DURIPARSER_SHARED_LIBS=OFF \
 			-DDBUILD_SHARED_LIBS=OFF \
	    -DURIPARSER_BUILD_CHAR=ON \
	    -DURIPARSER_ENABLE_INSTALL=OFF \
	    -DURIPARSER_WARNINGS_AS_ERRORS=OFF
	   "
	if [ "$TYPE" == "vs" ] ; then
		echo "building uriparser $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${ARCH}"
	    cd "build_${TYPE}_${ARCH}"
	    rm -f CMakeCache.txt *.a *.o *.lib
	    EXTRA_DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DURIPARSER_ENABLE_INSTALL=ON \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	    		${EXTRA_DEFS} \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
		 			${CMAKE_WIN_SDK} \
		 			-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		        -A "${PLATFORM}" \
		        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..
	elif [ "$TYPE" == "android" ]; then
		echo "Android "
		source ../../android_configure.sh $ABI cmake
	    echo "Mkdir build"
		mkdir -p build
		echo "Mkdir build/${ABI}"
		local BUILD_TO_DIR="build/${ABI}"

		cd build
		mkdir -p ${TYPE}
		cd ${TYPE}
		mkdir -p ${ABI}
		rm -f CMakeCache.txt *.a *.o
		CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        export CFLAGS=""
        export CPPFLAGS="-fvisibility-inlines-hidden -Wno-implicit-function-declaration"
        export CXXFLAGS="-fvisibility-inlines-hidden -Wno-implicit-function-declaration"
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""
    
		cmake \ 
			${DEFS} \
			-DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
 			-DANDROID_ABI=${ABI} \
 			-DANDROID_NDK=${NDK_ROOT} \
 			-DANDROID_STL=c++_shared \
 			-DANDROID_PLATFORM=${ANDROID_PLATFORM} \
 			-DBUILD_SHARED_LIBS=OFF \
       		-DCMAKE_C_COMPILER=${CC} \
      	 	-DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
      	 	-DCMAKE_C_COMPILER_RANLIB=${RANLIB} \
      	 	-DCMAKE_CXX_COMPILER_AR=${AR} \
      	 	-DCMAKE_C_COMPILER_AR=${AR} \
      	 	-DCMAKE_C_COMPILER=${CC} \
      	 	-DCMAKE_CXX_COMPILER=${CXX} \
      	 	-DCMAKE_C_FLAGS=${CFLAGS} \
      	 	-DCMAKE_CXX_FLAGS=${CXXFLAGS} \
         	-DANDROID_ABI=${ABI} \
         	-DCMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
         	-DCMAKE_C_STANDARD_LIBRARIES=${LIBS} \
         	-DCMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
         	-DANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
         	-DANDROID_TOOLCHAIN=clang++ \
         	-DCMAKE_BUILD_TYPE=Release \
         	-DCMAKE_SYSROOT=$SYSROOT \
         	-B${ABI} \
         	-G 'Unix Makefiles' ../..
        cd ${ABI}
 		make -j${PARALLEL_MAKE} VERBOSE=1
		make VERBOSE=1
		
		cd ../../..

	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		echo "int main(){return 0;}" > tool/uriparse.c
		mkdir -p "build_${TYPE}_${PLATFORM}"
    cd "build_${TYPE}_${PLATFORM}"
    rm -f CMakeCache.txt *.a *.o
		cmake .. \
						${DEFS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -D_GNU_SOURCE" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -D_GNU_SOURCE" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
      			-DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
         		-DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DHAVE_REALLOCARRAY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF \
            -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}

        cmake --build . --config Release --target install
        rm -f CMakeCache.txt
        cd ..      
      
	elif [ "$TYPE" == "emscripten" ]; then
			mkdir -p "build_${TYPE}"
			cd "build_${TYPE}"
			rm -f CMakeCache.txt *.a *.o *.wasm
        $EMSDK/upstream/emscripten/emcmake cmake .. \
          ${DEFS} \
          -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
          -DCMAKE_C_STANDARD=17 \
          -B . \
					-DBUILD_SHARED_LIBS=OFF \
					-DCMAKE_BUILD_TYPE=Release \
	       	-DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++17 -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c17 -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}"
        cmake --build . --config Release 
	    	cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/uriparser
	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -R "build_${TYPE}_${ARCH}/Release/include/" $1/
		cp -Rv "build_${TYPE}_${ARCH}/UriConfig.h" $1/include/uriparser/
    	cp -f "build_${TYPE}_${ARCH}/Release/lib/uriparser.lib" $1/lib/$TYPE/$PLATFORM/uriparser.lib
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		cp -r build_${TYPE}_${PLATFORM}/Release/include/* $1/include
		cp -Rv "build_${TYPE}_${PLATFORM}/UriConfig.h" $1/include/uriparser/
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${PLATFORM}/Release/lib/liburiparser.a $1/lib/$TYPE/$PLATFORM/uriparser.a
	elif [ "$TYPE" == "emscripten" ]; then
		cp -R include/uriparser/* $1/include/uriparser/
		mkdir -p $1/lib/$TYPE
		cp -Rv "build_${TYPE}/uriparser_wasm.wasm" $1/lib/$TYPE/uriparser.wasm
    elif [ "$TYPE" == "android" ]; then
		cp -R include/uriparser/* $1/include/uriparser/
		mkdir -p $1/lib/$TYPE/$ABI/
		cp -Rv build/$TYPE/$ABI/liburiparser.a $1/lib/$TYPE/$ABI/liburiparser.a
	fi
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v COPYING $1/license/
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
	elif [ "$TYPE" == "emscripten" ]; then
		if [ -d "build_${TYPE}" ]; then
		  rm -r build_${TYPE}     
		fi
	else
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "uriparser" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "uriparser" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
