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

 # 3.18.0
VER=31910
GIT_URL=https://github.com/danoli3/FreeImage
GIT_TAG=test3.19.0

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

	if [ "$TYPE" == "osx" ] ; then

		cp -rf $FORMULA_DIR/Makefile.osx Makefile.osx

		# set SDK using apothecary settings
		perl -pi -e tmp "s|MACOSX_SDK =.*|MACOSX_SDK = $OSX_SDK_VER|" Makefile.osx
		perl -pi -e tmp "s|MACOSX_MIN_SDK =.*|MACOSX_MIN_SDK = $OSX_MIN_SDK_VER|" Makefile.osx

	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then

		mkdir -p Dist/$TYPE
		mkdir -p builddir/$TYPE

		# copy across new Makefile for iOS.
		cp -v $FORMULA_DIR/Makefile.ios Makefile.ios

		# delete problematic file including a main fucntion
		# https://github.com/openframeworks/openFrameworks/issues/5980

		perl -pi -e "s/#define HAVE_SEARCH_H/\/\/#define HAVE_SEARCH_H/g" Source/LibTIFF4/tif_config.h

        #rm Source/LibWebP/src/dsp/dec_neon.c

        perl -pi -e "s/#define WEBP_ANDROID_NEON/\/\/#define WEBP_ANDROID_NEON/g" Source/LibWebP/./src/dsp/dsp.h
		
	elif [ "$TYPE" == "android" ]; then
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

	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		echo "building $TYPE | $PLATFORM"
        echo "--------------------"
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		
		  DEFS="-DCMAKE_C_STANDARD=17 \
		        -DCMAKE_CXX_STANDARD=17 \
		        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		        -DCMAKE_CXX_EXTENSIONS=OFF
		        -DBUILD_SHARED_LIBS=OFF \
		        -DCMAKE_INSTALL_INCLUDEDIR=include \
		        -DNO_BUILD_LIBRAWLITE=ON \
				-DNO_BUILD_OPENEXR=ON \
				-DNO_BUILD_WEBP=ON \
				-DNO_BUILD_JXR=ON \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/ios.toolchain.cmake
		        "         
		cmake  .. ${DEFS} \
			-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -fPIC ${FLAG_RELEASE}" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
			-DPLATFORM=$PLATFORM 
			 
		cmake --build . --config Release --target install
        cd ..
	elif [ "$TYPE" == "android" ] ; then
        
        source ../../android_configure.sh $ABI cmake
        local BUILD_TO_DIR=$BUILD_DIR/FreeImage/build/$TYPE/$ABI
        

        export EXTRA_LINK_FLAGS="-fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -Wno-trigraphs -fpascal-strings -Wno-missing-field-initializers -Wno-missing-prototypes -Wno-return-type -Wno-non-virtual-dtor -Wno-overloaded-virtual -Wno-exit-time-destructors -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wno-unused-variable -Wunused-value -Wno-empty-body -Wno-uninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-bool-conversion -Wno-enum-conversion -Wno-shorten-64-to-32 -Wno-newline-eof -Wno-c++11-extensions 
        -DHAVE_UNISTD_H=1 -DOPJ_STATIC -DNO_LCMS -D__ANSI__ -DDISABLE_PERF_MEASUREMENT -DLIBRAW_NODLL -DLIBRAW_LIBRARY_BUILD -DFREEIMAGE_LIB
         -fexceptions -fasm-blocks -fstrict-aliasing -Wdeprecated-declarations -Winvalid-offsetof -Wno-sign-conversion -Wmost -Wno-four-char-constants -Wno-unknown-pragmas -DNDEBUG -fPIC -fexceptions -fvisibility=hidden"
		export CFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c17"
		export CXXFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c++17"
		export LDFLAGS="$LDFLAGS $EXTRA_LINK_FLAGS -shared"

		source ../../android_configure.sh $ABI cmake
        rm -rf "build_${ABI}/"
        rm -rf "build_${ABI}/CMakeCache.txt"
		mkdir -p "build_$ABI"
		cd "./build_$ABI"
		CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        #export CFLAGS=""
        export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""

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
        	-DDISABLE_PERF_MEASUREMENT=ON \
        	-DLIBRAW_LIBRARY_BUILD=ON\
        	-DLIBRAW_NODLL=ON \
        	-DDHAVE_UNISTD_H=OFF \
        	-DPNG_ARM_NEON_OPT=OFF \
        	-DNDEBUG=OFF \
        	-DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DANDROID_STL=c++_shared \
        	-DCMAKE_C_STANDARD=17 \
        	-DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DNO_BUILD_LIBRAWLITE=ON \
			-DNO_BUILD_OPENEXR=ON \
			-DNO_BUILD_WEBP=ON \
			-DNO_BUILD_JXR=ON \
        	-G 'Unix Makefiles' ..

		make -j${PARALLEL_MAKE} VERBOSE=1
		cd ..

    elif [ "$TYPE" == "vs" ]; then
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN platform: $PLATFORM"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"
        
        
        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        	-DCMAKE_INSTALL_INCLUDEDIR=include \
        	-DNO_BUILD_LIBRAWLITE=ON \
			-DNO_BUILD_OPENEXR=ON \
			-DNO_BUILD_WEBP=ON \
			-DNO_BUILD_JXR=ON \
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
	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	-B build \
	    	-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
	    	-DNO_BUILD_LIBRAWLITE=ON \
			-DNO_BUILD_OPENEXR=ON \
			-DNO_BUILD_WEBP=ON \
			-DNO_BUILD_JXR=ON \
		    -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=. \
		    -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=. \
		    -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=. 
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

	# lib
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/libFreeImage.a" $1/lib/$TYPE/$PLATFORM/FreeImage.a
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/include	
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include
	    mkdir -p $1/lib/$TYPE
		cp Source/FreeImage.h $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImage.lib  
        cp -v "build_${TYPE}_${ARCH}/Debug/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImageD.lib
	elif [ "$TYPE" == "android" ] ; then
        cp Source/FreeImage.h $1/include
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
	    cp -v build_$ABI/libFreeImage.a $1/lib/$TYPE/$ABI/libFreeImage.a
    elif [ "$TYPE" == "emscripten" ]; then
        cp Source/FreeImage.h $1/include
        if [ -d $1/lib/$TYPE/ ]; then
            rm -r $1/lib/$TYPE/
        fi
        mkdir -p $1/lib/$TYPE
        cp -v build_${TYPE}/build/libFreeImage.a $1/lib/$TYPE/libfreeimage.a
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
	    if [ -d "build_${TYPE}" ]; then
            rm -r build_${TYPE}     
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
		make clean
		# run dedicated clean script
		clean.sh
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "freeimage" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "freeimage" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
