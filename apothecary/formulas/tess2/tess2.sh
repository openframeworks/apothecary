#!/usr/bin/env bash
#
# tess2
# Game and tools oriented refactored version of GLU tesselator
# https://code.google.com/p/libtess2/
#
# has no build system, only an old Xcode project
# we follow the Homebrew approach which is to use CMake via a custom CMakeLists.txt
# on ios, use some build scripts adapted from the Assimp project

# define the version
FORMULA_TYPES=( "osx" "vs" "emscripten" "ios" "watchos" "catos" "xros" "tvos" "android" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64" "msys2" )

# define the version
VER=1.0.2

# tools for git use
GIT_URL=https://github.com/memononen/libtess2
GIT_TAG=master

CSTANDARD=c17 # c89 | c99 | c11 | gnu11
CPPSTANDARD=c++17 # c89 | c99 | c11 | gnu11
COMPILER_CTYPE=clang # clang, gcc
COMPILER_CPPTYPE=clang++ # clang, gcc
STDLIB=libc++



# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
	downloader $GIT_URL/archive/refs/tags/v$VER.tar.gz
	tar -xzf v$VER.tar.gz
	mv libtess2-$VER tess2
	rm v$VER.tar.gz

	# check if the patch was applied, if not then patch

	cd tess2 
	patch -p1 -u -N  < $FORMULA_DIR/tess2.patch
	cd ..
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# copy in build script and CMake toolchains adapted from Assimp
	if [ "$TYPE" == "osx" ] ; then
		mkdir -p build
	fi
}

# executed inside the lib src dir
function build() {
	DEFS="
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include
	     "    
 
	cp -v $FORMULA_DIR/CMakeLists.txt .
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o 
		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
				-DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            	-DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_BUILD_TYPE=Release \
			    -DCMAKE_C_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD=17 \
			    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
			    -DCMAKE_CXX_EXTENSIONS=OFF \
			    -DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include
		cmake --build . --config Release --target install
		cd ..

	elif [ "$TYPE" == "vs" ] ; then
		cp -v $FORMULA_DIR/CMakeLists.txt .
		echo "building tess2 $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${PLATFORM}"
	    cd "build_${TYPE}_${PLATFORM}"
	    rm -f CMakeCache.txt *.lib *.o 
	    cmake .. ${DEFS} \
	    	-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        -DBUILD_SHARED_LIBS=OFF \
	        ${CMAKE_WIN_SDK} \
	        -DCMAKE_CXX_FLAGS=-DNDEBUG \
	        -DCMAKE_C_FLAGS=-DNDEBUG \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -A "${PLATFORM}" \
	        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..
	elif [ "$TYPE" == "android" ] ; then
 
        # setup android paths / variables
	    source ../../android_configure.sh $ABI cmake
        
		cp -v $FORMULA_DIR/CMakeLists.txt .

		mkdir -p "build_$ABI"
		cd "./build_$ABI"
		rm -f CMakeCache.txt *.a *.o
		export CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        
        export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""
        cmake -D CMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
        	-D CMAKE_OSX_SYSROOT:PATH==${SYSROOT} \
      		-D CMAKE_C_COMPILER==${CC} \
     	 	-D CMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_C_COMPILER_RANLIB=${RANLIB} \
     	 	-D CMAKE_CXX_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER_AR=${AR} \
     	 	-D CMAKE_C_COMPILER=${CC} \
     	 	-D CMAKE_CXX_COMPILER=${CXX} \
     	 	-D CMAKE_C_FLAGS=${CFLAGS} \
     	 	-D CMAKE_CXX_FLAGS=${CPPFLAGS} \
        	-D ANDROID_ABI=${ABI} \
        	-D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
        	-D CMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
        	-D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
        	-D ANDROID_TOOLCHAIN=clang \
        	-DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
			-DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
        	-DCMAKE_C_STANDARD=17 \
        	-DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
        	-G 'Unix Makefiles' ..
		make -j${PARALLEL_MAKE} VERBOSE=1
		cd ..

	elif [ "$TYPE" == "emscripten" ] ; then
    	cp -v $FORMULA_DIR/CMakeLists.txt .
    	mkdir -p build
    	cd build
    	rm -f CMakeCache.txt *.a *.o 
    	emcmake cmake .. \
			-DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
			-DCMAKE_BUILD_TYPE="Release" \
			-DCMAKE_INSTALL_LIBDIR="lib" \
			-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCPU_BASELINE='' \
			-DCPU_DISPATCH='' \
			-DCV_TRACE=OFF \
			-DCMAKE_C_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128 ${FLAG_RELEASE}" \
			-DCMAKE_CXX_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128 ${FLAG_RELEASE}" \
    		-DCMAKE_CXX_FLAGS="-DNDEBUG -pthread" \
    		-DCMAKE_C_FLAGS="-DNDEBUG -pthread"
    	emmake make -j${PARALLEL_MAKE}
	elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linux" ] || [ "$TYPE" == "msys2" ]; then
	    mkdir -p build
	    cd build
	    rm -f CMakeCache.txt *.a *.o 
	    cp -v $FORMULA_DIR/Makefile .
	    cp -v $FORMULA_DIR/tess2.make .
	    make config=release tess2
	elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "linuxaarch64" ]; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
        fi
	    mkdir -p build
	    cd build
	    cp -v $FORMULA_DIR/Makefile .
	    cp -v $FORMULA_DIR/tess2.make .
	    make config=release tess2
	    cd ..
	    mkdir -p build/$TYPE
	    mv build/libtess2.a build/$TYPE
	else
		mkdir -p build/$TYPE
		cd build/$TYPE
		cmake -G "Unix Makefiles" -DCMAKE_CXX_COMPILER=/mingw32/bin/g++.exe -DCMAKE_C_COMPILER=/mingw32/bin/gcc.exe -DCMAKE_CXX_FLAGS=-DNDEBUG -DCMAKE_C_FLAGS=-DNDEBUG ../../
		make
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	rm -rf $1/include
	mkdir -p $1/include
	cp -Rv Include/* $1/include/
	. "$SECURE_SCRIPT"
	# lib
	mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/ 
    	cp -f "build_${TYPE}_${PLATFORM}/Release/lib/tess2.lib" $1/lib/$TYPE/$PLATFORM/tess2.lib
		secure $1/lib/$TYPE/$PLATFORM/tess2.lib tess2
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libtess2.a" $1/lib/$TYPE/$PLATFORM/libtess2.a
        secure $1/lib/$TYPE/$PLATFORM/libtess2.a tess2
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
	elif [ "$TYPE" == "emscripten" ]; then
		cp -v build/libtess2.a $1/lib/$TYPE/libtess2.a
		secure $1/lib/$TYPE/tess2.lib tess2
	elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linux" ] || [ "$TYPE" == "msys2" ]; then
		cp -v build/libtess2.a $1/lib/$TYPE/libtess2.a
		secure $1/lib/$TYPE/libtess2.a tess2
	elif [ "$TYPE" == "android" ]; then
	    rm -rf $1/lib/$TYPE/$ABI
	    mkdir -p $1/lib/$TYPE/$ABI
		cp -v build_$ABI/libtess2.a $1/lib/$TYPE/$ABI/libtess2.a
		secure $1/lib/$TYPE/$ABI/libtess2.a tess2
	else
		cp -v build/$TYPE/libtess2.a $1/lib/$TYPE/libtess2.a
		secure $1/lib/$TYPE/libtess2.a tess2
	fi

	# copy license files
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v LICENSE.txt $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
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
		make clean
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "tess2" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
