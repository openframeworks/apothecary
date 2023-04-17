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
VER=3184
GIT_URL=https://github.com/danoli3/FreeImage
GIT_TAG=3.18.4

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

        	unset ARCH IOS_DEVROOT IOS_SDKROOT IOS_CC TARGET_NAME HEADER
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

            unset ARCH IOS_DEVROOT IOS_SDKROOT IOS_CC TARGET_NAME HEADER
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
		    #			libfreeimage-armv7s.a \
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
        local BUILD_TO_DIR=$BUILD_DIR/FreeImage/build/$TYPE/$ABI
        source ../../android_configure.sh $ABI cmake
        

        export EXTRA_LINK_FLAGS="-fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -Wno-trigraphs -fpascal-strings -Wno-missing-field-initializers -Wno-missing-prototypes -Wno-return-type -Wno-non-virtual-dtor -Wno-overloaded-virtual -Wno-exit-time-destructors -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wno-unused-variable -Wunused-value -Wno-empty-body -Wno-uninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wno-constant-conversion -Wno-int-conversion -Wno-bool-conversion -Wno-enum-conversion -Wno-shorten-64-to-32 -Wno-newline-eof -Wno-c++11-extensions -DHAVE_UNISTD_H=1 -DOPJ_STATIC -DNO_LCMS -D__ANSI__ -DDISABLE_PERF_MEASUREMENT -DLIBRAW_NODLL -DLIBRAW_LIBRARY_BUILD -DFREEIMAGE_LIB -fexceptions -fasm-blocks -fstrict-aliasing -Wdeprecated-declarations -Winvalid-offsetof -Wno-sign-conversion -Wmost -Wno-four-char-constants -Wno-unknown-pragmas -DNDEBUG -fPIC -fexceptions -fvisibility=hidden"
		export CFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c17"
		export CXXFLAGS="$CFLAGS $EXTRA_LINK_FLAGS -DNDEBUG -ffast-math -DPNG_ARM_NEON_OPT=0 -DDISABLE_PERF_MEASUREMENT -frtti -std=c++17"
		export LDFLAGS="$LDFLAGS $EXTRA_LINK_FLAGS -shared"

        make clean -f Makefile.android
        make -j${PARALLEL_MAKE} \
        	CC=${CC} \
        	AR=${AR} \
        	CXX=${CXX} \
    		RANLIB=${RANLIB} \
    		LD=${LD} \
    		STRIP=${STRIP} \
        	-f Makefile.android \
        	libfreeimage.a
      
        mkdir -p $BUILD_DIR/FreeImage/Dist/$ABI
        mv libfreeimage.a $BUILD_DIR/FreeImage/Dist/$ABI
    elif [ "$TYPE" == "vs" ]; then
        export CFLAGS="-pthread"
		export CXXFLAGS="-pthread"

		echo "building $TYPE | $ARCH | $VS_VER"
        echo "--------------------"
        local generatorName="Visual Studio "
        generatorName+=$VS_VER_GEN

        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DLIBRARY_SUFFIX=${ARCH}"

		mkdir -p build_vs$ARCH
	    cd build_vs$ARCH

        if [ $VS_VER == 15 ] ; then
            if [ $ARCH == 32 ] ; then                
                cmake .. -G "$generatorName" $buildOpts
                vs-build "FreeImage.sln" build "Release|Win32"
            elif [ $ARCH == 64 ] ; then
                generatorName+=' Win64'
                cmake .. -G "$generatorName"  $buildOpts
                vs-build "FreeImage.sln" build "Release|x64"
            fi
        else		
			if [ $ARCH == 32 ] ; then	                
	                generatorName+=''
	                echo "generatorName $generatorName -A Win32 "
	                cmake .. -G "$generatorName" -A Win32 $buildOpts
	                cmake --build . --config release
	                #vs-build "FreeImage.sln" build "Release|Win32"
	        elif [ $ARCH == 64 ] ; then	           
	            generatorName+=''
	            echo "generatorName $generatorName -A x64"
	            cmake .. -G "$generatorName" -A x64 $buildOpts
	            cmake --build . --config release
	            #vs-build "FreeImage.sln" build "Release|x64"
	        elif [ $ARCH == "arm" ]; then	            
	            generatorName+=' '
	            echo "generatorName $generatorName -A ARM"
	            cmake .. -G "Visual Studio 16 2019" -A ARM $buildOpts
	            #cmake .. -G "$generatorName" -A ARM $buildOpts
	            cmake --build . --config release
	            #vs-build "FreeImage.sln" build "Release|ARM"
	        elif [ $ARCH == "arm64" ] ; then	            
	            generatorName+=''
	            echo "generatorName $generatorName -A ARM64"
	            cmake .. -G "Visual Studio 16 2019" -A ARM64 $buildOpts
	            #cmake .. -G "$generatorName" -A ARM64 $buildOpts
	            cmake --verbose --build . --config release 
	            #vs-build "FreeImage.sln" build "Release|ARM64"
	        fi
        fi
        cd ..
    elif [ "$TYPE" == "emscripten" ]; then
        export CFLAGS="-pthread"
		export CXXFLAGS="-pthread"
		export CMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
		echo "$CMAKE_TOOLCHAIN_FILE"


		mkdir -p build_$TYPE
	    cd build_$TYPE

	    cmake .. -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release
	    emmake make -j${PARALLEL_MAKE}

        # local BUILD_TO_DIR=$BUILD_DIR/FreeImage/build/$TYPE
        # rm -rf $BUILD_DIR/FreeImagePatched
        # cp -r $BUILD_DIR/FreeImage $BUILD_DIR/FreeImagePatched
        # echo "#include <unistd.h>" > $BUILD_DIR/FreeImagePatched/Source/ZLib/gzlib.c
        # cat $BUILD_DIR/FreeImage/Source/ZLib/gzlib.c >> $BUILD_DIR/FreeImagePatched/Source/ZLib/gzlib.c
        # echo "#include <unistd.h>" > $BUILD_DIR/FreeImagePatched/Source/ZLib/gzread.c
        # cat $BUILD_DIR/FreeImage/Source/ZLib/gzread.c >> $BUILD_DIR/FreeImagePatched/Source/ZLib/gzread.c
        # echo "#include <unistd.h>" > $BUILD_DIR/FreeImagePatched/Source/ZLib/gzwrite.c
        # cat $BUILD_DIR/FreeImage/Source/ZLib/gzread.c >> $BUILD_DIR/FreeImagePatched/Source/ZLib/gzwrite.c
        
        # echo "#include <byteswap.h>" > $BUILD_DIR/FreeImagePatched/Source/LibJXR/image/decode/segdec.c
        # echo "#define _byteswap_ulong __bswap_32" >> $BUILD_DIR/FreeImagePatched/Source/LibJXR/image/decode/segdec.c
        # cat $BUILD_DIR/FreeImage/Source/LibJXR/image/decode/segdec.c >> $BUILD_DIR/FreeImagePatched/Source/LibJXR/image/decode/segdec.c
        # echo "#include <wchar.h>" > $BUILD_DIR/FreeImagePatched/Source/LibJXR/jxrgluelib/JXRGlueJxr.c
        # cat $BUILD_DIR/FreeImage/Source/LibJXR/jxrgluelib/JXRGlueJxr.c >> $BUILD_DIR/FreeImagePatched/Source/LibJXR/jxrgluelib/JXRGlueJxr.c
        # sed -i "s/CXXFLAGS ?=/CXXFLAGS ?= -std=c++17/g" "$BUILD_DIR/FreeImagePatched/Makefile.gnu"
        # cd $BUILD_DIR/FreeImagePatched
        # which emmake
        #   #emmake make clean -f Makefile.gnu
        # emmake Makefile.gnu libfreeimage.a
        # mkdir -p $BUILD_DIR/FreeImage/Dist/
        # mv libfreeimage.a $BUILD_DIR/FreeImage/Dist/
        # cd $BUILD_DIR/FreeImage
        #rm -rf $BUILD_DIR/FreeImagePatched
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
		mkdir -p $1/include #/Win32
		#mkdir -p $1/include/x64
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v build_vs$ARCH/Release/FreeImage.lib $1/lib/$TYPE/Win32/FreeImage.lib
			#cp -v build_vs$ARCH/Release/FreeImage.dll $1/lib/$TYPE/Win32/FreeImage.dll
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v build_vs$ARCH/Release/FreeImage.lib $1/lib/$TYPE/x64/FreeImage.lib
			#cp -v build_vs$ARCH/Release/FreeImage.dll $1/lib/$TYPE/x64/FreeImage.dll
		elif [ $ARCH == "arm" ]; then
			mkdir -p $1/lib/$TYPE/ARM
			cp -v build_vs$ARCH/Release/FreeImage.lib $1/lib/$TYPE/ARM/FreeImage.lib
			#cp -v build_vs$ARCH/Release/FreeImage.dll $1/lib/$TYPE/ARM/FreeImage.dll
		fi
	elif [ "$TYPE" == "msys2" ] ; then
		mkdir -p $1/include #/Win32
		#mkdir -p $1/include/x64
	    cp -v Dist/x32/*.h $1/include #/Win32/
		#cp -v Dist/x64/*.h $1/include/x64/
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v Dist/x32/FreeImage.lib $1/lib/$TYPE/Win32/FreeImage.lib
			cp -v Dist/x32/FreeImage.dll $1/lib/$TYPE/Win32/FreeImage.dll
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v Dist/x64/FreeImage.lib $1/lib/$TYPE/x64/FreeImage.lib
			cp -v Dist/x64/FreeImage.dll $1/lib/$TYPE/x64/FreeImage.dll
		elif [ $ARCH == "arm" ]; then
			mkdir -p $1/lib/$TYPE/ARM
			cp -v Dist/x64/FreeImage.lib $1/lib/$TYPE/ARM/FreeImage.lib
			cp -v Dist/x64/FreeImage.dll $1/lib/$TYPE/ARM/FreeImage.dll
		fi
	elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -v Dist/*.h $1/include
        if [ -d $1/lib/$TYPE/ ]; then
            rm -r $1/lib/$TYPE/
        fi
       	mkdir -p $1/lib/$TYPE
		cp -v Dist/$TYPE/freeimage.a $1/lib/$TYPE/freeimage.a

	elif [ "$TYPE" == "android" ] ; then
        cp Source/FreeImage.h $1/include
        if [ -d $1/lib/$TYPE/$ABI ]; then
            rm -r $1/lib/$TYPE/$ABI
        fi
        mkdir -p $1/lib/$TYPE/$ABI
        cp -rv Dist/$ABI/*.a $1/lib/$TYPE/$ABI/
    elif [ "$TYPE" == "emscripten" ]; then
        cp Source/FreeImage.h $1/include
        if [ -d $1/lib/$TYPE/ ]; then
            rm -r $1/lib/$TYPE/
        fi
        mkdir -p $1/lib/$TYPE
        cp -rv Dist/libfreeimage.a $1/lib/$TYPE/
	fi

    # copy license files
    rm -rf $1/license # remove any older files if exists
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
		rm -f builddir/$TYPE
		rm -f builddir
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
