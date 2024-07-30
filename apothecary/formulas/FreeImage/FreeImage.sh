#!/usr/bin/env bash
#
# Free Image
# cross platform image io
# http://freeimage.sourceforge.net
#
# Makefile build system,
# some Makefiles are out of date so patching/modification may be required

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten")

# define the version

FORMULA_DEPENDS=( "zlib" "libpng" )

VER=31990
GIT_URL=https://github.com/danoli3/FreeImage
GIT_TAG=3.19.9

# download the source code and unpack it into LIB_NAME
function download() {

		echo " $APOTHECARY_DIR downloading $GIT_TAG"	
		. "$DOWNLOADER_SCRIPT"
	
		URL="$GIT_URL/archive/refs/tags/$GIT_TAG.tar.gz"
		# For win32, we simply download the pre-compiled binaries.
		curl -sSL -o FreeImage-$GIT_TAG.tar.gz $URL

		tar -xzf FreeImage-$GIT_TAG.tar.gz
		mv FreeImage-$GIT_TAG FreeImage
		rm FreeImage-$GIT_TAG.tar.gz
	
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
			
	if [ "$TYPE" == "android" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/FreeImage
	    cd $BUILD_DIR/FreeImage
	    perl -pi -e "s/#define HAVE_SEARCH_H/\/\/#define HAVE_SEARCH_H/g" Source/LibTIFF4/tif_config.h

        #rm Source/LibWebP/src/dsp/dec_neon.c

        perl -pi -e "s/#define WEBP_ANDROID_NEON/\/\/#define WEBP_ANDROID_NEON/g" Source/LibWebP/./src/dsp/dsp.h

	elif [ "$TYPE" == "vs" ]; then
		echo "vs"
	fi
}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		echo "building $TYPE | $PLATFORM"
        echo "--------------------"
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o 
		LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
	    ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
	    ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"
		
		  DEFS="
		        -DBUILD_SHARED_LIBS=OFF \
		        -DCMAKE_INSTALL_INCLUDEDIR=include \
		        -DBUILD_LIBRAWLITE=OFF \
				-DBUILD_OPENEXR=OFF \
				-DBUILD_WEBP=ON \
				-DBUILD_JXR=OFF \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake
		        "         
		cmake  .. ${DEFS} \
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_BUILD_TYPE=Release \
			-DPNG_ROOT=${LIBPNG_ROOT} \
			-DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
			-DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_ZLIB=OFF \
            -DBUILD_TESTS=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
	        -GXcode \
			-DPLATFORM=$PLATFORM 
			 
		cmake --build . --config Release --target install
        cd ..
	elif [ "$TYPE" == "android" ] ; then
        
        source ../../android_configure.sh $ABI cmake
        local BUILD_TO_DIR=$BUILD_DIR/FreeImage/build/$TYPE/$ABI
        

        export EXTRA_LINK_FLAGS="-fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -Wno-trigraphs -fpascal-strings -Wno-missing-field-initializers -Wno-missing-prototypes -Wno-return-type -Wno-non-virtual-dtor -Wno-overloaded-virtual -Wno-exit-time-destructors -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wno-unused-variable -Wunused-value -Wno-empty-body -Wno-uninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-bool-conversion -Wno-enum-conversion -Wno-shorten-64-to-32 -Wno-newline-eof -Wno-c++11-extensions 
        -DHAVE_UNISTD_H=1 -DOPJ_STATIC -DNO_LCMS -D__ANSI__ -DDISABLE_PERF_MEASUREMENT -DLIBRAW_NODLL -DLIBRAW_LIBRARY_BUILD -DFREEIMAGE_LIB
         -fexceptions -fasm-blocks -fstrict-aliasing -Wdeprecated-declarations -Winvalid-offsetof -Wno-sign-conversion -Wmost -Wno-four-char-constants -Wno-unknown-pragmas -DNDEBUG -fPIC -fexceptions -fvisibility=hidden"
		export CFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c${C_STANDARD}"
		export CXXFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c++${CPP_STANDARD}"
		export LDFLAGS="$LDFLAGS $EXTRA_LINK_FLAGS -shared"

		source ../../android_configure.sh $ABI cmake
        rm -rf "build_${ABI}/"
        rm -rf "build_${ABI}/CMakeCache.txt"
		mkdir -p "build_$ABI"
		cd "./build_$ABI"
		rm -f CMakeCache.txt *.a *.o 
		CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        #export CFLAGS=""
        export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""

       	LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$ABI/libpng.a"	

        cmake -D CMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
        	-D CMAKE_OSX_SYSROOT:PATH=${SYSROOT} \
      		-D CMAKE_C_COMPILER=${CC} \
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
        	-D CMAKE_BUILD_TYPE=Release \
        	-D FT_REQUIRE_HARFBUZZ=FALSE \
        	-DPNG_ROOT=${LIBPNG_ROOT} \
			-DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
        	-DDISABLE_PERF_MEASUREMENT=ON \
        	-DLIBRAW_LIBRARY_BUILD=ON\
        	-DLIBRAW_NODLL=ON \
        	-DENABLE_VISIBILITY=OFF \
        	-DDHAVE_UNISTD_H=OFF \
        	-DPNG_ARM_NEON_OPT=OFF \
        	-DNDEBUG=OFF \
        	-DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
			-DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
        	-DCMAKE_C_STANDARD=${C_STANDARD} \
        	-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_LIBRAWLITE=OFF \
			-DBUILD_OPENEXR=OFF \
			-DBUILD_WEBP=OFF \
			-DBUILD_JXR=OFF \
        	-G 'Unix Makefiles' ..

		make -j${PARALLEL_MAKE} VERBOSE=1
		cd ..

    elif [ "$TYPE" == "vs" ]; then
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN platform: $PLATFORM"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"
		rm -f CMakeCache.txt *.a *.o *.lib
		LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib"        
        
        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        	-DCMAKE_INSTALL_INCLUDEDIR=include \
        	-DBUILD_LIBRAWLITE=OFF \
        	-DBUILD_LIBPNG=OFF \
			-DBUILD_OPENEXR=OFF \
			-DBUILD_WEBP=OFF \
			-DBUILD_JXR=OFF \
			-DENABLE_VISIBILITY=OFF \
			-DPNG_ROOT=${LIBPNG_ROOT} \
			-DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
			-DBUILD_SHARED_LIBS=OFF"	
		env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}"
		cmake  .. ${DEFS} \
			-UCMAKE_CXX_FLAGS \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
			-DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
			-DCMAKE_INSTALL_LIBDIR="build_${TYPE}_${ARCH}" \
			-DCMAKE_BUILD_TYPE=Release \
			-D CMAKE_VERBOSE_MAKEFILE=ON \
		    -DCMAKE_INSTALL_PREFIX=. \
			${CMAKE_WIN_SDK} \
			-A "${PLATFORM}" \
			-G "${GENERATOR_NAME}"
        cmake --build . --target install --config Release

        env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}"
		cmake  .. ${DEFS} \
			-UCMAKE_CXX_FLAGS \
	        -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}" \
			-DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG}" \
			-DCMAKE_INSTALL_LIBDIR="build_${TYPE}_${ARCH}" \
			-DCMAKE_BUILD_TYPE=Debug \
			-D CMAKE_VERBOSE_MAKEFILE=ON \
		    -DCMAKE_INSTALL_PREFIX=. \
			${CMAKE_WIN_SDK} \
			-A "${PLATFORM}" \
			-G "${GENERATOR_NAME}"

        cmake --build . --target install --config Debug 
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
		mkdir -p build_$TYPE
	    cd build_$TYPE

	    LIBPNG_ROOT="$LIBS_ROOT/libpng/"
		LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
		LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng16.a"

		ZLIB_ROOT="$LIBS_ROOT/zlib/"
	    ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
	    ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

	    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"
		
	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	-B build \
	    	-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
	    	-DBUILD_LIBRAWLITE=OFF \
			-DBUILD_OPENEXR=OFF \
			-DENABLE_VISIBILITY=OFF \
			-DBUILD_WEBP=OFF \
			-DBUILD_JXR=OFF \
			-DBUILD_TESTS=OFF \
			-DCMAKE_CXX_FLAGS=" ${FLAG_RELEASE} " \
			-DCMAKE_C_FLAGS="${FLAG_RELEASE} " \
			-DPNG_ROOT=${LIBPNG_ROOT} \
			-DPNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            -DBUILD_LIBPNG=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_ZLIB=OFF \
		    -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include
	    cmake --build build --target install --config Release
	    cd ..
	else
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o
		cmake -S . -B build \
	    	-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DENABLE_VISIBILITY=OFF \
	    	-DBUILD_LIBRAWLITE=OFF \
			-DBUILD_OPENEXR=OFF \
			-DBUILD_WEBP=OFF \
			-DBUILD_JXR=OFF \
			-DBUILD_LIBPNG=ON \
			-DBUILD_ZLIB=ON \
			-DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
	    cmake --build build --target install --config Release
	    cd ..
          
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	if [ -d $1/include ]; then
	    rm -rf $1/include
	fi
	mkdir -p $1/include
	. "$SECURE_SCRIPT"
	# lib
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libFreeImage.a" $1/lib/$TYPE/$PLATFORM/FreeImage.a
		cp Source/FreeImage.h $1/include
		secure $1/lib/$TYPE/$PLATFORM/FreeImage.a FreeImage.pkl
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include
	    mkdir -p $1/lib/$TYPE
		cp Source/FreeImage.h $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImage.lib  
        cp -v "build_${TYPE}_${ARCH}/Debug/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImageD.lib
        secure $1/lib/$TYPE/$PLATFORM/FreeImage.lib FreeImage.pkl
	elif [ "$TYPE" == "android" ] ; then
        cp Source/FreeImage.h $1/include
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
	    cp -v build_$ABI/libFreeImage.a $1/lib/$TYPE/$ABI/libFreeImage.a
        secure $1/lib/$TYPE/$ABI/libFreeImage.a FreeImage.pkl
    elif [ "$TYPE" == "emscripten" ]; then
        cp Source/FreeImage.h $1/include
        if [ -d $1/lib/$TYPE/$PLATFORM/ ]; then
            rm -r $1/lib/$TYPE/$PLATFORM/
        fi
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v build_${TYPE}/build/libFreeImage.a $1/lib/$TYPE/$PLATFORM/libfreeimage.a
		secure $1/lib/$TYPE/$PLATFORM/libfreeimage.a FreeImage.pkl
	fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v license-fi.txt $1/license/
    cp -v license-gplv2.txt $1/license/
    cp -v license-gplv3.txt $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "android" ] ; then
		if [ -d "build_${ABI}" ]; then
            rm -r build_${ABI}     
        fi
	elif [ "$TYPE" == "emscripten" ] ; then
		if [ -d $1/lib/$TYPE/$PLATFORM/ ]; then
            rm -r $1/lib/$TYPE/$PLATFORM/
        fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
    elif [ "$TYPE" == "vs" ] ; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
	else
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}     
        fi
		# run dedicated clean script
		clean.sh
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "FreeImage" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
