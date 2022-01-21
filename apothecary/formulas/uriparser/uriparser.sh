#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx"  "android"  "emscripten" ) 
	# ios" "tvos" "vs" "msys2" # need to convert to cmake


# define the version by sha
VER=0.9.6

# tools for git use
GIT_URL=https://github.com/uriparser/uriparser
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	#wget -nv --no-check-certificate $GIT_URL/releases/download/uriparser-$VER/uriparser-$VER.tar.bz2
	#tar -xjf uriparser-$VER.tar.bz2
	#mv uriparser-$VER uriparser
	#rm uriparser*.tar.bz2
	git clone $GIT_URL uriparser
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "vs" ] ; then
		cp -vr $FORMULA_DIR/vs2015 win32/
	fi
}

# executed inside the lib src dir
function build() {
	rm -f CMakeCache.txt

	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		cd win32/vs2015

		if [[ $VS_VER -gt 14 ]]; then
			vs-upgrade uriparser.sln
		fi

		if [ $ARCH == 32 ] ; then
			vs-build uriparser.sln Build "Release|Win32"
		elif [ $ARCH == 64 ] ; then
			vs-build uriparser.sln Build "Release|x64"
		fi

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
	    # make install
	    cd ../..
	elif [ "$TYPE" == "msys2" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE
		./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared
		echo "int main(){return 0;}" > tool/uriparse.c
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
            IOS_ARCHS="armv7 arm64 x86_64 " #armv7s
        fi

		for IOS_ARCH in ${IOS_ARCHS}; do
			source ../../ios_configure.sh $TYPE $IOS_ARCH
            # mkdir -p ${IOS_ARCH}
			# cd ${IOS_ARCH}
   #          echo "Compiling for $IOS_ARCH"
    	    
            local BUILD_TO_DIR=$BUILD_DIR/uriparser/build/$TYPE/$IOS_ARCH
            ./configure --prefix=$BUILD_TO_DIR --disable-test --disable-doc --enable-static --disable-shared --host=$HOST --target=$HOST
            make clean
            make -j${PARALLEL_MAKE}
            make install
     #        cmake \
	 			# -DURIPARSER_BUILD_TESTS=OFF \
	 			# -DURIPARSER_BUILD_DOCS=OFF \
	 			# -DURIPARSER_BUILD_TOOLS=ON \
	 			# -DBUILD_SHARED_LIBS=OFF \
	    #      	-DCMAKE_BUILD_TYPE=Release \
	 			# -DBUILD_SHARED_LIBS=OFF \
	    #    		-DCMAKE_C_COMPILER=${CC} \
	    #   	 	-DCMAKE_CXX_COMPILER=${CXX} \
	    #   	 	-DCMAKE_OSX_SYSROOT=${SYSROOT} \
	    #   	 	-DCMAKE_SYSTEM_NAME="${TYPE}" \
	    #   	 	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	    #   	 	-DCMAKE_XCODE_ATTRIBUTE_ENABLE_BITCODE=ON \
	    #   	 	-DCMAKE_C_FLAGS="" \
	    #   	 	-DCMAKE_CXX_FLAGS="" \
	    #      	-G 'Unix Makefiles' ../..
	    #      	cmake --build . --config Release
	         # cd ..
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "${TYPE}" == "ios" ]; then
            lipo -create build/$TYPE/x86_64/lib/liburiparser.a \
                         build/$TYPE/armv7/lib/liburiparser.a \
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
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		else
			PLATFORM="x64"
		fi
		cp -Rv include/* $1/include
		mkdir -p $1/lib/$TYPE/$PLATFORM
		cp -v win32/uriparser.lib $1/lib/$TYPE/$PLATFORM/uriparser.lib
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		cp -Rv build/$TYPE/liburiparser.a $1/lib/$TYPE/uriparser.a
	elif [ "$TYPE" == "msys2" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/uriparser/* $1/include/uriparser/
		# copy lib
		cp -Rv build/$TYPE/lib/liburiparser.a $1/lib/$TYPE/liburiparser.a
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
