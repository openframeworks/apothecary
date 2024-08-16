#!/usr/bin/env /bash
#
# A Massively Spiffy Yet Delicately Unobtrusive Compression Library
# http://zlib.net/

FORMULA_TYPES=( "vs" "osx" "emscripten" "ios" "watchos" "catos" "xros" "tvos" "linux" "linux64" "linuxarmv6l" "linuxarmv7l" "linuxaarch64"  )
FORMULA_DEPENDS=( )

# define the version
VER=1.3.1
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/madler/zlib/releases/download/v$VER/zlib-$VER.tar.gz
GIT_TAG=v$VER


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
	# . "$DOWNLOADER_SCRIPT"
	# downloader https://github.com/danoli3/zlib/raw/patch-1/CMakeLists.txt
	cp -v "$FORMULA_DIR"/*.txt ./

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
        rm -f CMakeCache.txt *.lib *.o *.a
        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}"
        cmake .. \
            -G "${GENERATOR_NAME}" \
            -A "${PLATFORM}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=ON \
		    -DZLIB_BUILD_EXAMPLES=OFF \
		    -DSKIP_EXAMPLE=ON \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -UCMAKE_CXX_FLAGS \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
		    ${CMAKE_WIN_SDK} 
        cmake --build . --config Release --target install
        cd ..
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o 
		cmake .. \
			-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=OFF \
		    -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
		    -DZLIB_BUILD_EXAMPLES=OFF \
		    -DSKIP_EXAMPLE=ON \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
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
    elif [ "$TYPE" == "android" ] ; then

		source $APOTHECARY_DIR/android_configure.sh $ABI cmake
		mkdir -p "build_${TYPE}_${ABI}"
		cd "build_${TYPE}_${ABI}"
		rm -f CMakeCache.txt *.a *.o
		export CFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -std=${CPP_STANDARD}"
		export CXXFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -std=${C_STANDARD}"

		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -std=${CPP_STANDARD} " \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} -std=${C_STANDARD} " \
				-DCMAKE_C_COMPILER=${CC} \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_C_STANDARD=${C_STANDARD} \
	            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
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
	        	-D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
	        	-D ANDROID_TOOLCHAIN=clang \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..
	elif [ "$TYPE" == "emscripten" ] ; then
		mkdir -p build_${TYPE}_${PLATFORM}
	    cd build_${TYPE}_${PLATFORM}
	    rm -f CMakeCache.txt *.a *.o  *.js
	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	-DCMAKE_INSTALL_LIBDIR="lib" \
	    	-DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
	    	-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
	    	-D BUILD_SHARED_LIBS=OFF \
		    -DZLIB_BUILD_EXAMPLES=OFF \
		    -DSKIP_EXAMPLE=ON \
		    -G 'Unix Makefiles' \
		    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	    	-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS=" ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="${FLAG_RELEASE}" \
			-DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include 
        #     -DCMAKE_INSTALL_INCLUDEDIR=include 
        # $EMSDK/upstream/emscripten/emmake make
        # $EMSDK/upstream/emscripten/emmake make install
	 	cmake --build . --config Release --target install 
	    cd ..
    elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxaarch64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
	    
		echoVerbose "building $TYPE | $ARCH "
        echoVerbose "--------------------"
	    mkdir -p "build_${TYPE}_${ARCH}"
	    cd "build_${TYPE}_${ARCH}"
	    rm -f CMakeCache.txt *.a *.o *.so
	    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
	        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF"         
	    cmake .. ${DEFS} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -Iinclude" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -Iinclude" \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
		    -DZLIB_BUILD_EXAMPLES=OFF \
		    -DSKIP_EXAMPLE=ON \
	        -DCMAKE_SYSTEM_NAME=$TYPE \
	        -DCMAKE_INSTALL_PREFIX=Release \
    		-DCMAKE_SYSTEM_PROCESSOR=$ARCH \
    		-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_INSTALL_INCLUDEDIR=include 
	    cmake --build . --target install --config Release
	    cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	mkdir -p $1/include
	. "$SECURE_SCRIPT"
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/ > /dev/null 2>&1
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a
        secure $1/lib/$TYPE/$PLATFORM/zlib.a 

		cp -vR "build_${TYPE}_${PLATFORM}/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/
       
        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
		sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
		sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
		export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

	elif [ "$TYPE" == "vs" ] ; then    
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/ > /dev/null 2>&1
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/z.lib" $1/lib/$TYPE/$PLATFORM/zlib.lib > /dev/null 2>&1
        secure $1/lib/$TYPE/$PLATFORM/zlib.lib

        cp -vR "build_${TYPE}_${ARCH}/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/
       
        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
		sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
		sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
		export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"
    elif [ "$TYPE" == "android" ] ; then
		mkdir -p $1/lib/$TYPE/$ABI/
		cp -v "build_${TYPE}_${ABI}/Release/lib/libz.a" $1/lib/$TYPE/$ABI/zlib.a
		cp -RT "build_${TYPE}_${ABI}/Release/include/" $1/include
        secure $1/lib/$TYPE/$ABI/zlib.a
	elif [ "$TYPE" == "emscripten" ] ; then
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/
		mkdir -p $1/lib/$TYPE/$PLATFORM
		cp -v "build_${TYPE}_$PLATFORM/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a
        secure $1/lib/$TYPE/$PLATFORM/zlib.a
        cp -v "build_${TYPE}_$PLATFORM/Release/share/pkgconfig/zlib.pc" $1/lib/$TYPE/$PLATFORM/zlib.pc
        
        PKG_FILE="$1/lib/$TYPE/$PLATFORM/zlib.pc"
		sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
		sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
		sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
		export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxaarch64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
		mkdir -p $1/include    
	    mkdir -p $1/lib/$TYPE/$PLATFORM
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/"* $1/include/ > /dev/null 2>&1
        cp -v "build_${TYPE}_${ARCH}/Release/lib/libz.a" $1/lib/$TYPE/$PLATFORM/zlib.a > /dev/null 2>&1
        secure $1/lib/$TYPE/$PLATFORM/zlib.a
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
	if [[ "$TYPE" =~ ^(vs|osx|ios|tvos|xros|catos|watchos|emscripten)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
    elif [ "$TYPE" == "android" ] ; then
		if [ -d "build_${TYPE}_${ABI}" ]; then
			rm -r build_${TYPE}_${ABI}     
		fi
    elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] || [ "$TYPE" == "linuxaarch64" ] || [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "msys2" ]; then
		if [ -d "build_${TYPE}_${ARCH}" ]; then
			rm -r build_${TYPE}_${ARCH}     
		fi
	else
		make uninstall
		make clean
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "zlib" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
