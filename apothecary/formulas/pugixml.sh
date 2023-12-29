#!/usr/bin/env bash
#
# pugixml
# pugixml is a c++ xml parser
# http://pugixml.org/
#
# uses a makeifle build system

FORMULA_TYPES=( "emscripten" "osx" "vs" "ios" "tvos" "android" )

# define the version by sha
VER=1.13

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
    if [ "$TYPE" == "emscripten" ]; then
        rm -f libpugixml.bc

		# Compile the program
		emcc -O2 \
			 -Wall \
			 -Iinclude \
			 -c src/pugixml.cpp \
			 -o libpugixml.bc
	elif [ "$TYPE" == "vs" ] ; then
		echo "building glfw $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"

        LIBS_ROOT=$(realpath $LIBS_DIR)

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_INSTALL_LIBDIR=lib"        
     
        cmake .. ${DEFS} \
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
        mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -f "build_${TYPE}_${ARCH}/Release/lib/pugixml.lib" $1/lib/$TYPE/$PLATFORM/pugixml.lib
        cp -f "build_${TYPE}_${ARCH}/Debug/lib/pugixml.lib" $1/lib/$TYPE/$PLATFORM/pugixmlD.lib
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
	else
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "pugixml" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "pugixml" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
