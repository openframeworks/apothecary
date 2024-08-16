#!/usr/bin/env bash
#
# pugixml
# pugixml is a c++ xml parser
# http://pugixml.org/
#
# uses a makeifle build system
FORMULA_TYPES=( "emscripten" "osx" "vs" "ios" "watchos" "xros" "catos" "tvos" "android" )
FORMULA_DEPENDS=( )

# define the version by sha
VER=1.14
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/zeux/pugixml
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
	downloader https://github.com/zeux/pugixml/releases/download/v$VER/pugixml-$VER.tar.gz
	mkdir pugixml
	tar xzf pugixml-$VER.tar.gz --directory pugixml --strip-components=1
	rm "pugixml-$VER.tar.gz"
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
}

# executed inside the lib src dir
function build() {
	export DEFS="  -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib"        
    if [ "$TYPE" == "emscripten" ]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}" 
		rm -f CMakeCache.txt *.a *.o *.a *.js
		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
		    	-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    	-DPLATFORM=$PLATFORM \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_BUILD_TYPE=Release \
			    -DCMAKE_C_STANDARD=${C_STANDARD} \
			    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			    -DCMAKE_CPP_FLAGS="${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="${FLAG_RELEASE}" \
			    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
			    -DCMAKE_CXX_EXTENSIONS=OFF \
			    -DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include \
				-DCMAKE_INSTALL_LIBDIR=lib 
		$EMSDK/upstream/emscripten/emmake make
        $EMSDK/upstream/emscripten/emmake make install
		# cmake --build . --config Release --target install
		cd ..
	elif [ "$TYPE" == "vs" ] ; then
		echo "building glfw $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.lib
        LIBS_ROOT=$(realpath $LIBS_DIR)

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        cmake .. ${DEFS} \
       		-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_RELEASE} ${VS_C_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_RELEASE} ${VS_C_FLAGS}" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DSTATIC_CRT=OFF \
            -DBUILD_TESTS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_BUILD_TYPE=Release \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release --target install

        cmake .. ${DEFS} \
        	-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_DEBUG} ${VS_C_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_DEBUG} ${VS_C_FLAGS}" \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DSTATIC_CRT=OFF \
            -DBUILD_TESTS=OFF \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
         cmake --build . --config Debug --target install

         cd ..

	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI make
        #export CFLAGS="$CFLAGS -I${NDK_ROOT}/sysroot/usr/include/${ANDROID_PREFIX} -I${NDK_ROOT}/sysroot/usr/include/"
		# Compile the program
		$CXX -Oz $CPPFLAGS $CXXFLAGS \
			 -Wall \
			 -fPIC \
			 -std=c++${CPP_STANDARD} \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o src/pugixml.o $LDFLAGS -shared -v
        $AR ruv libpugixml.a src/pugixml.o
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o 
		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_BUILD_TYPE=Release \
				-DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
			    -DCMAKE_C_STANDARD=${C_STANDARD} \
			    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
			    -DCMAKE_CXX_EXTENSIONS=OFF \
			    -DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include \
				-DCMAKE_INSTALL_LIBDIR=lib 
		cmake --build . --config Release --target install
		cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include
	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	cp -Rv src/pugiconfig.hpp $1/include/pugiconfig.hpp
	cp -Rv src/pugixml.hpp $1/include/pugixml.hpp
	# sed -i '$1/include/pugixml.hpp' 's/pugiconfig.hpp/pugiconfig.hpp' $1/include/pugixml.hpp
	. "$SECURE_SCRIPT"
	if [ "$TYPE" == "vs" ] ; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -f "build_${TYPE}_${ARCH}/Release/lib/pugixml.lib" $1/lib/$TYPE/$PLATFORM/pugixml.lib
        cp -f "build_${TYPE}_${ARCH}/Debug/lib/pugixml.lib" $1/lib/$TYPE/$PLATFORM/pugixmlD.lib
        secure $1/lib/$TYPE/$PLATFORM/pugixml.lib
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include 
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libpugixml.a" $1/lib/$TYPE/$PLATFORM/libpugixml.a
        secure $1/lib/$TYPE/$PLATFORM/libpugixml.a pugixml.pkl
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		cp -Rv libpugixml.a $1/lib/$TYPE/$ABI/libpugixml.a
        secure $1/lib/$TYPE/$ABI/libpugixml.a pugixml.pkl
	elif [ "$TYPE" == "emscripten" ] ; then
	    mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib/libpugixml.a" $1/lib/$TYPE/$PLATFORM/libpugixml.a 
        secure $1/lib/$TYPE/$PLATFORM/libpugixml.a
	fi
	# copy license file
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	mkdir -p $1/license
	cp -v readme.txt $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten)$ ]]; then
		rm -f *.a
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            # Delete the folder and its contents
            rm -r build_${TYPE}_${PLATFORM}     
        fi
	else
		make clean
	fi
}

function secure() {
    . "$SECURE_SCRIPT"
    secure $1/lib/$TYPE/$PLATFORM/pugixml.lib
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "pugixml" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
