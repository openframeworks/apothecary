#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system


FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" "emscripten" )



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
}

# executed inside the lib src dir
function build() {
	rm -f CMakeCache.txt || true

	if [ "$TYPE" == "vs" ] ; then
		echo "building uriparser $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
	    echo "--------------------"
	    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
	    mkdir -p "build_${TYPE}_${ARCH}"
	    cd "build_${TYPE}_${ARCH}"
	    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD=17 \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"         
	    cmake .. ${DEFS} \
	        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
	        -DCMAKE_INSTALL_LIBDIR="lib" \
	        -DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=OFF \
 			${CMAKE_WIN_SDK} \
	        -A "${PLATFORM}" \
	        -G "${GENERATOR_NAME}"
	    cmake --build . --config Release --target install
	    cd ..
	elif [ "$TYPE" == "android" ]; then
		echo "Android "
		source ../../android_configure.sh $ABI cmake
	    #cp $FORMULA_DIR/CMakeLists.txt .


	    echo "Mkdir build"
		mkdir -p build
		echo "Mkdir build/${ABI}"
		local BUILD_TO_DIR="build/${ABI}"

		cd build
		mkdir -p ${TYPE}
		cd ${TYPE}
		mkdir -p ${ABI}
		#echo "cd build/${ABI}"
		#cp $FORMULA_DIR/CMakeLists.txt .
		CFLAGS=""
        export CMAKE_CFLAGS="$CFLAGS"
        export CFLAGS=""
        export CPPFLAGS="-fvisibility-inlines-hidden -Wno-implicit-function-declaration"
        export CXXFLAGS="-fvisibility-inlines-hidden -Wno-implicit-function-declaration"
        export CMAKE_LDFLAGS="$LDFLAGS"
       	export LDFLAGS=""
    
		cmake \
			-DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
 			-DANDROID_ABI=${ABI} \
 			-DANDROID_NDK=${NDK_ROOT} \
 			-DANDROID_STL=c++_shared \
 			-DANDROID_PLATFORM=${ANDROID_PLATFORM} \
 			-DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=OFF \
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
        	-DCMAKE_C_STANDARD=17 \
        	-DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
         	-B${ABI} \
         	-G 'Unix Makefiles' ../..
        cd ${ABI}
 		make -j${PARALLEL_MAKE} VERBOSE=1
		make VERBOSE=1
		
		cd ../../..

	elif [ "$TYPE" == "osx" ]; then

		echo "macOS "
        export CFLAGS=""
        export CXXFLAGS="-mmacosx-version-min=${OSX_MIN_SDK_VER}"

        export LDFLAGS=" "
	    local BUILD_TO_DIR="build/${TYPE}"

	    mkdir -p build
		echo "int main(){return 0;}" > tool/uriparse.c
		cd build
		mkdir -p ${TYPE}
		cd ${TYPE}

		cmake \
 			-DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=ON \
 			-DBUILD_SHARED_LIBS=OFF \
         	-DCMAKE_BUILD_TYPE=Release \
         	-DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
         	-DCMAKE_C_FLAGS=${CFLAGS} \
         	-DCMAKE_CXX_FLAGS=${CXXFLAGS} \
         	-G 'Unix Makefiles' ../.. 

		#./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared
        make clean
		make -j${PARALLEL_MAKE}

	    make install
	elif [ "$TYPE" == "emscripten" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE
		mkdir -p build
		local BUILD_TO_DIR="build/${TYPE}"
		echo "int main(){return 0;}" > tool/uriparse.c
		cd build
		mkdir -p ${TYPE}
		cd ${TYPE}
  		export CFLAGS="-fvisibility-inlines-hidden  -Wno-implicit-function-declaration "
        export CXXFLAGS="-fvisibility-inlines-hidden  -Wno-implicit-function-declaration"
		cmake \
 			-DURIPARSER_BUILD_TESTS=OFF \
 			-DURIPARSER_BUILD_DOCS=OFF \
 			-DURIPARSER_BUILD_TOOLS=ON \
 			-DBUILD_SHARED_LIBS=OFF \
         	-DCMAKE_BUILD_TYPE=Release \
         	-DCMAKE_C_FLAGS=${CFLAGS} \
      	 	-DCMAKE_CXX_FLAGS=${CXXFLAGS} \
         	-G 'Unix Makefiles' ../.. 
		#emconfigure ./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared
        emmake make clean
		emmake make -j${PARALLEL_MAKE}
	    # emmake make install
	    cd ..
	    cd ..
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		mkdir -p build
		# cd build

		mkdir -p "build/${TYPE}"
		# cd ${TYPE}

        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="arm64 x86_64 " #armv7s
        fi

		for IOS_ARCH in ${IOS_ARCHS}; do
			source ../../ios_configure.sh $TYPE $IOS_ARCH
            mkdir -p ${IOS_ARCH}
			cd ${IOS_ARCH}
            echo "Compiling for $IOS_ARCH"
    	    
            local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE/$IOS_ARCH
            # ./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared --host=$HOST --target=$HOST
            cmake ../ \
	 			-DURIPARSER_BUILD_TESTS=OFF \
	 			-DURIPARSER_BUILD_DOCS=OFF \
	 			-DURIPARSER_BUILD_TOOLS=ON \
	 			-DBUILD_SHARED_LIBS=OFF \
	         	-DCMAKE_BUILD_TYPE=Release \
	 			-DBUILD_SHARED_LIBS=OFF \
	       		-DCMAKE_C_COMPILER=${CC} \
	      	 	-DCMAKE_CXX_COMPILER=${CXX} \
	      	 	-DCMAKE_OSX_SYSROOT=${SYSROOT} \
	      	 	-DCMAKE_SYSTEM_NAME="${TYPE}" \
	      	 	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	      	 	-DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=ON \
	      	 	-DCMAKE_C_FLAGS="" \
	      	 	-DCMAKE_CXX_FLAGS="" \
	 			-DBUILD_SHARED_LIBS=OFF \
	         	-DCMAKE_BUILD_TYPE=Release \
	         	-G 'Unix Makefiles' 
	         	cmake --build . --config Release

	         make clean
             make -j${PARALLEL_MAKE}
             #make install 
	         cd ..

        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "${TYPE}" == "ios" ]; then
            lipo -create build/$TYPE/x86_64/lib/liburiparser.a \
                         build/$TYPE/arm64/lib/liburiparser.a \
                        -output build/$TYPE/lib/liburiparser.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create build/$TYPE/x86_64/lib/liburiparser.a \
                         build/$TYPE/arm64/lib/liburiparser.a \
                        -output build/$TYPE/lib/liburiparser.a
        fi
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
		cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
    	cp -f "build_${TYPE}_${ARCH}/Release/lib/uriparser.lib" $1/lib/$TYPE/$PLATFORM/uriparser.lib
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib

		cp -Rv build/$TYPE/lib/liburiparser.a $1/lib/$TYPE/uriparser.a
	elif [ "$TYPE" == "emscripten" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		mkdir -p $1/lib/$TYPE
		cp -Rv build/$TYPE/liburiparser.a $1/lib/$TYPE/liburiparser.a
    elif [ "$TYPE" == "android" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		mkdir -p $1/lib/$TYPE/$ABI/
		cp -Rv build/$TYPE/$ABI/liburiparser.a $1/lib/$TYPE/$ABI/liburiparser.a
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	elif [ "$TYPE" == "emscripten" ]; then
		rm -f CMakeCache.txt
		rm -f build/emscripten
		rm -r build
		make clean
	elif [ "$TYPE" == "android" ]; then
		rm -f CMakeCache.txt
		rm -f build/liburiparser.a
		rm -r  build
		make clean
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
