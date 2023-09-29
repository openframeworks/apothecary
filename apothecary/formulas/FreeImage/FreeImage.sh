#!/usr/bin/env bash
#
# Free Image
# cross platform image io
# http://freeimage.sourceforge.net
#
# Makefile build system,
# some Makefiles are out of date so patching/modification may be required

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" "emscripten")

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

	if [ "$TYPE" == "osx" ] ; then
		make -j${PARALLEL_MAKE} -f Makefile.osx

		strip -x Dist/libfreeimage.a

	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then

		# Notes:
        # --- for 3.1+ Must use "-DNO_LCMS -D__ANSI__ -DDISABLE_PERF_MEASUREMENT" to compile LibJXR
		export TOOLCHAIN=$XCODE_DEV_ROOT/Toolchains/XcodeDefault.xctoolchain
		export TARGET_IOS

        local IOS_ARCHS
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64"
        fi

        local STDLIB="libc++"
        local CURRENTPATH=`pwd`

        SDKVERSION=""
        if [ "${TYPE}" == "tvos" ]; then
            SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
        elif [ "$TYPE" == "ios" ]; then
            SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
        fi


        DEVELOPER=$XCODE_DEV_ROOT
		TOOLCHAIN=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain
		VERSION=$VER

        # Validate environment
        case $XCODE_DEV_ROOT in
            *\ * )
                echo "Your Xcode path contains whitespaces, which is not supported."
                exit 1
                ;;
        esac
        case $CURRENTPATH in
            *\ * )
                echo "Your path contains whitespaces, which is not supported by 'make install'."
                exit 1
                ;;
        esac

        mkdir -p "builddir/$TYPE"

        # loop through architectures! yay for loops!
        for IOS_ARCH in ${IOS_ARCHS}
        do

        	unset IOS_DEVROOT IOS_SDKROOT IOS_CC TARGET_NAME HEADER
            unset CC CPP CXX CXXCPP CFLAGS CXXFLAGS LDFLAGS LD AR AS NM RANLIB LIBTOOL
            unset EXTRA_PLATFORM_CFLAGS EXTRA_PLATFORM_LDFLAGS IOS_PLATFORM NO_LCMS

            export ARCH=$IOS_ARCH

            local EXTRA_PLATFORM_CFLAGS=""
			export EXTRA_PLATFORM_LDFLAGS=""
			if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
			then
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVSimulator"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneSimulator"
                fi
			else
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVOS"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneOS"
                fi
			fi

			export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
			export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
			export BUILD_TOOLS="${DEVELOPER}"

			MIN_IOS_VERSION=$IOS_MIN_SDK_VER
		    # min iOS version for arm64 is iOS 7

		    if [[ "${IOS_ARCH}" == "arm64" || "${IOS_ARCH}" == "x86_64" ]]; then
		    	MIN_IOS_VERSION=9.0 # 7.0 as this is the minimum for these architectures
		    elif [ "${IOS_ARCH}" == "i386" ]; then
		    	MIN_IOS_VERSION=9.0 # 6.0 to prevent start linking errors
		    fi

            if [ "${TYPE}" == "tvos" ]; then
    		    MIN_TYPE=-mtvos-version-min=
    		    if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
    		    	MIN_TYPE=-mtvos-simulator-version-min=
    		    fi
            elif [ "$TYPE" == "ios" ]; then
                MIN_TYPE=-miphoneos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mios-simulator-version-min=
                fi
            fi

            BITCODE=""
            if [[ "$TYPE" == "tvos" ]] || [[ "${IOS_ARCH}" == "arm64" ]]; then
                BITCODE=-fembed-bitcode;
                MIN_IOS_VERSION=13.0
            fi

			export TARGET_NAME="$CURRENTPATH/libfreeimage-$IOS_ARCH.a"
			export HEADER="Source/FreeImage.h"

			export CC=$TOOLCHAIN/usr/bin/clang
			export CPP=$TOOLCHAIN/usr/bin/clang++
			export CXX=$TOOLCHAIN/usr/bin/clang++
			export CXXCPP=$TOOLCHAIN/usr/bin/clang++

			export LD=$TOOLCHAIN/usr/bin/ld
			export AR=$TOOLCHAIN/usr/bin/ar
			export AS=$TOOLCHAIN/usr/bin/as
			export NM=$TOOLCHAIN/usr/bin/nm
			export RANLIB=$TOOLCHAIN/usr/bin/ranlib
			export LIBTOOL=$TOOLCHAIN/usr/bin/libtool

		  	export EXTRA_PLATFORM_CFLAGS="$EXTRA_PLATFORM_CFLAGS"
			export EXTRA_PLATFORM_LDFLAGS="$EXTRA_PLATFORM_LDFLAGS -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -Wl,-dead_strip -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include/ $MIN_TYPE$MIN_IOS_VERSION "

		   	EXTRA_LINK_FLAGS="-arch $IOS_ARCH $BITCODE -fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -Wno-trigraphs -fpascal-strings -Oz -Wno-missing-field-initializers -Wno-missing-prototypes -Wno-return-type -Wno-non-virtual-dtor -Wno-overloaded-virtual -Wno-exit-time-destructors -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wno-unused-variable -Wunused-value -Wno-empty-body -Wno-uninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-bool-conversion -Wno-enum-conversion -Wno-shorten-64-to-32 -Wno-newline-eof -Wno-c++11-extensions -DHAVE_UNISTD_H=1 -DOPJ_STATIC -DNO_LCMS -D__ANSI__ -DDISABLE_PERF_MEASUREMENT -DLIBRAW_NODLL -DLIBRAW_LIBRARY_BUILD -DFREEIMAGE_LIB -fexceptions -fasm-blocks -fstrict-aliasing -Wdeprecated-declarations -Winvalid-offsetof -Wno-sign-conversion -Wmost -Wno-four-char-constants -Wno-unknown-pragmas -DNDEBUG -fPIC -fexceptions -fvisibility=hidden"
			EXTRA_FLAGS="$EXTRA_LINK_FLAGS $BITCODE -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT $MIN_TYPE$MIN_IOS_VERSION -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -I${CROSS_TOP}/SDKs/${CROSS_SDK}/usr/include/"

		    export CC="$CC $EXTRA_FLAGS"
			export CFLAGS="-arch $IOS_ARCH $EXTRA_FLAGS -std=c17 -Wno-implicit-function-declaration"
			export CXXFLAGS="$EXTRA_FLAGS -std=c++17 -stdlib=libc++"
			export LDFLAGS="-arch $IOS_ARCH $EXTRA_PLATFORM_LDFLAGS $EXTRA_LINK_FLAGS $MIN_TYPE$MIN_IOS_VERSION"
			export LDFLAGS_PHONE=$LDFLAGS

			mkdir -p "$CURRENTPATH/builddir/$TYPE/$IOS_ARCH"
			echo "-----------------"
			echo "Building FreeImage-${VER} for ${PLATFORM} ${SDKVERSION} ${IOS_ARCH} : iOS Minimum=$MIN_IOS_VERSION"
			set +e

			echo "Running make for ${IOS_ARCH}"
			echo "Please stand by..."

			# run makefile
			make -j${PARALLEL_MAKE} -f Makefile.ios

     		echo "Completed Build for $IOS_ARCH of FreeImage"

     		mv -v libfreeimage-$IOS_ARCH.a Dist/$TYPE/libfreeimage-$IOS_ARCH.a

     		cp Source/FreeImage.h Dist

            unset IOS_DEVROOT IOS_SDKROOT IOS_CC TARGET_NAME HEADER
            unset CC CPP CXX CXXCPP CFLAGS CXXFLAGS LDFLAGS LD AR AS NM RANLIB LIBTOOL
            unset EXTRA_PLATFORM_CFLAGS EXTRA_PLATFORM_LDFLAGS IOS_PLATFORM NO_LCMS

		done

		echo "Completed Build for $TYPE"

        echo "-----------------"
		echo `pwd`
		echo "Finished for all architectures."
		mkdir -p "$CURRENTPATH/builddir/$TYPE/$IOS_ARCH"
		LOG="$CURRENTPATH/builddir/$TYPE/build-freeimage-${VER}-lipo.log"

		cd Dist/$TYPE/
		# link into universal lib
		echo "Running lipo to create fat lib"
		echo "Please stand by..."
        if [[ "${TYPE}" == "tvos" ]] ; then
            lipo -create libfreeimage-arm64.a \
                    libfreeimage-x86_64.a \
                    -output freeimage.a
        elif [[ "$TYPE" == "ios" ]]; then
		    lipo -create libfreeimage-armv7.a \
					libfreeimage-arm64.a \
					libfreeimage-x86_64.a \
					-output freeimage.a
        fi

		lipo -info freeimage.a

        if [[ "$TYPE" == "ios" ]]; then
    		echo "--------------------"
    		echo "Stripping any lingering symbols"
    		echo "Please stand by..."
    		# validate all stripped debug:
    		strip -x freeimage.a
        fi
		cd ../../

		echo "--------------------"
		echo "Build Successful for FreeImage $TYPE $VER"

		# include copied in the makefile to libs/$TYPE/include
		unset TARGET_IOS
		unset TOOLCHAIN

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
        	-DOPJ_STATIC=ON \
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
		echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
		mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"
        DEFS="-DLIBRARY_SUFFIX=${ARCH}"	
		cmake  .. ${DEFS} \
		-DCMAKE_C_STANDARD=17 \
		-DCMAKE_CXX_STANDARD=17 \
		-DCMAKE_CXX_STANDARD_REQUIRED=ON \
		-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
		-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
		-DCMAKE_CXX_EXTENSIONS=OFF \
		-DBUILD_SHARED_LIBS=ON \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_LIBDIR="build_${TYPE}_${ARCH}" \
		-DNO_BUILD_LIBRAWLITE=ON \
		-DNO_BUILD_OPENEXR=ON \
		-DNO_BUILD_WEBP=ON \
		-DNO_BUILD_JXR=ON \
		-DCMAKE_INSTALL_PREFIX=Release \
        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
		${CMAKE_WIN_SDK} \
		-A "${PLATFORM}" \
		-G "${GENERATOR_NAME}"
        cmake --build . --target install --config Release 
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
            -DCMAKE_INSTALL_INCLUDEDIR=include
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
	if [ "$TYPE" == "osx" ] ; then
	    cp -v Dist/*.h $1/include
		mkdir -p $1/lib/$TYPE
		cp -v Dist/libfreeimage.a $1/lib/$TYPE/freeimage.a
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include
	    mkdir -p $1/lib/$TYPE
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${ARCH}/Release/FreeImage.lib" $1/lib/$TYPE/$PLATFORM/FreeImage.lib  
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -v Dist/*.h $1/include
        if [ -d $1/lib/$TYPE/ ]; then
            rm -r $1/lib/$TYPE/
        fi
       	mkdir -p $1/lib/$TYPE
		cp -v Dist/$TYPE/freeimage.a $1/lib/$TYPE/freeimage.a

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
		make clean
		rm -rf Dist
		rm -f *.a
		rm -f lib
	elif [ "$TYPE" == "emscripten" ] ; then
	    make clean
	    rm -rf Dist
		rm -f *.a
		rm -f build_emscripten
		rm -f lib
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
		# clean up compiled libraries
		make clean
		rm -rf Dist
		rm -f *.a *.lib

		rm -f lib
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
