#!/usr/bin/env bash
#
# pugixml
# pugixml is a c++ xml parser
# http://pugixml.org/
#
# uses a makeifle build system

FORMULA_TYPES=( "emscripten" "osx" "vs" "ios" "tvos" "android" )

# define the version by sha
VER=1.11.4

# tools for git use
GIT_URL=https://github.com/zeux/pugixml
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	wget -nv http://github.com/zeux/pugixml/releases/download/v$VER/pugixml-$VER.tar.gz
	mkdir pugixml
	tar xzf pugixml-$VER.tar.gz --directory pugixml --strip-components=1
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : #noop
}

# executed inside the lib src dir
function build() {
    if [ "$TYPE" == "emscripten" ]; then
        rm -f libpugixml.bc

		# Compile the program
		emcc -O2 \
			 -Wall \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o libpugixml.bc
	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd scripts

		if [[ $VS_VER == 14 ]]; then
			if [ $ARCH == 32 ] ; then
					vs-build "pugixml_vs2017.vcxproj" build "Release|Win32"
					vs-build "pugixml_vs2017.vcxproj" build "Debug|Win32"
			else
					vs-build "pugixml_vs2017.vcxproj" build "Release|x64"
					vs-build "pugixml_vs2017.vcxproj" build "Debug|x64"
			fi
		elif [[ $VS_VER == 13 ]]; then
			if [ $ARCH == 32 ] ; then
					vs-build "pugixml_vs2015.vcxproj" build "Release"
					vs-build "pugixml_vs2015.vcxproj" build "Debug"
			else
					vs-build "pugixml_vs2015.vcxproj" build "Release|x64"
					vs-build "pugixml_vs2015.vcxproj" build "Debug|x64"
			fi
		else 
			if [ $ARCH == 32 ] ; then
					vs-build "pugixml_vs2019.vcxproj" build "Release|Win32"
					vs-build "pugixml_vs2019.vcxproj" build "Debug|Win32"
			elif [ $ARCH == 64 ] ; then
					vs-build "pugixml_vs2019.vcxproj" build "Release|x64"
					vs-build "pugixml_vs2019.vcxproj" build "Debug|x64"
			else
					vs-build "pugixml_vs2019.vcxproj" build "Release|ARM"
					vs-build "pugixml_vs2019.vcxproj" build "Debug|ARM"
			fi

		fi

	elif [ "$TYPE" == "android" ]; then
        source ../../android_configure.sh $ABI make
        #export CFLAGS="$CFLAGS -I${NDK_ROOT}/sysroot/usr/include/${ANDROID_PREFIX} -I${NDK_ROOT}/sysroot/usr/include/"
		# Compile the program
		$CXX -Oz $CPPFLAGS $CXXFLAGS \
			 -Wall \
			 -fPIC \
			 -std=c++17 \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o src/pugixml.o $LDFLAGS -shared -v
        $AR ruv libpugixml.a src/pugixml.o
	elif [ "$TYPE" == "osx" ]; then
        export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		clang++ -O2  $CFLAGS \
			 -Wall \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o src/pugixml.o
        libtool src/pugixml.o -o libpugixml.a
        ranlib libpugixml.a
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
        fi
		for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
    	    source ../../ios_configure.sh $TYPE $IOS_ARCH
            export CFLAGS="$CFLAGS -I$LIBS_DIR/libxml2/include"
		    $CXX -O2 \
			     $CFLAGS \
			     -c src/pugixml.cpp \
			     -o src/pugixml.o
            ar ruv libpugixml_$IOS_ARCH.a src/pugixml.o
        done

        if [ "$TYPE" == "ios" ]; then
            lipo -create libpugixml_x86_64.a \
                         libpugixml_armv7.a \
                         libpugixml_arm64.a \
                        -output libpugixml.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create libpugixml_x86_64.a \
                         libpugixml_arm64.a \
                        -output libpugixml.a
        fi
        ranlib libpugixml.a
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	# Standard *nix style copy.
	# copy headers
	cp -Rv src/pugiconfig.hpp $1/include/pugiconfig.hpp
	cp -Rv src/pugixml.hpp $1/include/pugixml.hpp
	# sed -i '$1/include/pugixml.hpp' 's/pugiconfig.hpp/pugiconfig.hpp' $1/include/pugixml.hpp

	if [ "$TYPE" == "vs" ] ; then
		if [[ $VS_VER -gt 17 ]]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "scripts/vs2022/Win32_Release/pugixml.lib" $1/lib/$TYPE/Win32/pugixml.lib
				cp -v "scripts/vs2022/Win32_Debug/pugixml.lib" $1/lib/$TYPE/Win32/pugixmld.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "scripts/vs2022/x64_Release/pugixml.lib" $1/lib/$TYPE/x64/pugixml.lib
				cp -v "scripts/vs2022/x64_Debug/pugixml.lib" $1/lib/$TYPE/x64/pugixmld.lib
			elif [ $ARCH == "arm" ]; then
				mkdir -p $1/lib/$TYPE/ARM
				# TODO
			fi
		elif [[ $VS_VER -gt 16 ]]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "scripts/vs2019/Win32_Release/pugixml.lib" $1/lib/$TYPE/Win32/pugixml.lib
				cp -v "scripts/vs2019/Win32_Debug/pugixml.lib" $1/lib/$TYPE/Win32/pugixmld.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "scripts/vs2019/x64_Release/pugixml.lib" $1/lib/$TYPE/x64/pugixml.lib
				cp -v "scripts/vs2019/x64_Debug/pugixml.lib" $1/lib/$TYPE/x64/pugixmld.lib
			elif [ $ARCH == "arm" ]; then
				mkdir -p $1/lib/$TYPE/ARM
				# TODO
			fi
		elif [[ $VS_VER -gt 14 ]]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "scripts/vs2017/Win32_Release/pugixml.lib" $1/lib/$TYPE/Win32/pugixml.lib
				cp -v "scripts/vs2017/Win32_Debug/pugixml.lib" $1/lib/$TYPE/Win32/pugixmld.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "scripts/vs2017/x64_Release/pugixml.lib" $1/lib/$TYPE/x64/pugixml.lib
				cp -v "scripts/vs2017/x64_Debug/pugixml.lib" $1/lib/$TYPE/x64/pugixmld.lib
			fi
		
		elif [[ $VS_VER -gt 13 ]]; then
			if [ $ARCH == 32 ] ; then
				mkdir -p $1/lib/$TYPE/Win32
				cp -v "scripts/vs2015/Win32_Release/pugixml.lib" $1/lib/$TYPE/Win32/pugixml.lib
				cp -v "scripts/vs2015/Win32_Debug/pugixml.lib" $1/lib/$TYPE/Win32/pugixmld.lib
			elif [ $ARCH == 64 ] ; then
				mkdir -p $1/lib/$TYPE/x64
				cp -v "scripts/vs2015/x64_Release/pugixml.lib" $1/lib/$TYPE/x64/pugixml.lib
				cp -v "scripts/vs2015/x64_Debug/pugixml.lib" $1/lib/$TYPE/x64/pugixmld.lib
			fi
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv libpugixml.a $1/lib/$TYPE/pugixml.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
		cp -Rv libpugixml.a $1/lib/$TYPE/$ABI/libpugixml.a
	elif [ "$TYPE" == "emscripten" ] ; then
	    mkdir -p $1/lib/$TYPE
		# copy lib
		cp -Rv libpugixml.bc $1/lib/$TYPE/libpugixml.bc
	fi


	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v readme.txt $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
	else
		make clean
	fi
}
