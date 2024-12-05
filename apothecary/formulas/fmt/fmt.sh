#!/usr/bin/env bash
#
# {fmt} is an open-source formatting library providing a fast and safe alternative to C stdio and C++ iostreams.
# https://github.com/fmtlib/fmt

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" "linux64" "linuxaarch64" )
FORMULA_DEPENDS=(  ) 

# define the version
VER=11.0.2

# tools for git use
GIT_URL=https://github.com/fmtlib/fmt
URL=${GIT_URL}/archive/refs/tags/${VER}
GIT_TAG=master
SHA=
BUILD_ID=1
DEFINES=""

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"

	git clone --branch $GIT_TAG --depth=1 $GIT_URL 

	# if [ "$TYPE" == "vs" ] ; then
	# 	downloader "${URL}.zip"
	# 	unzip -q "${VER}.zip"
	# 	mv "fmt-${VER}" fmt
	# 	rm "${VER}.zip"
	# else 
	# 	downloader "${URL}.tar.gz"
	# 	tar -xf "${VER}.tar.gz"
	# 	mv "fmt-${VER}" fmt
	# 	rm "${VER}.tar.gz"
	# fi
	

}

# prepare the build environment, executed inside the lib src dir
function prepare() {

	echoVerbose "prepare"
	# . "$DOWNLOADER_SCRIPT"
	rm -f ./CMakeLists.txt
	cp -v $FORMULA_DIR/CMakeLists.txt ./CMakeLists.txt
	
}

# executed inside the lib src dir
function build() {
	LIBS_ROOT=$(realpath $LIBS_DIR)

	DEFINES="
		    -DCMAKE_C_STANDARD=${C_STANDARD} \
		    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
		    -DBUILD_SHARED_LIBS=OFF \
		    -DFMT_MASTER_PROJECT=OFF \
		    -DFMT_MODULE=OFF \
		    -DFMT_SYSTEM_HEADERS=OFF \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include"
	
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o
		cmake .. ${DEFINES} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_BUILD_TYPE=Release \
				-DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=OFF \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..	
	elif [ "$TYPE" == "vs" ] ; then
		echoVerbose "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
	  	echoVerbose "--------------------"
	  	GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 

	  	mkdir -p "build_${TYPE}_${ARCH}"
		cd "build_${TYPE}_${ARCH}"
		rm -f CMakeCache.txt *.lib *.o

  		env CXXFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
  		env CFLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${CALLING_CONVENTION}"
		cmake .. ${DEFINES} \
			-B . \
	    	-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_BUILD_TYPE=Release \
		    -A "${PLATFORM}" \
		    -G "${GENERATOR_NAME}" \
		    ${CMAKE_WIN_SDK} \
		    -UCMAKE_CXX_FLAGS \
		    -UCMAKE_C_FLAGS \
		    -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
	      	-DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
		    -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
		    -D BUILD_SHARED_LIBS=OFF

		cmake --build . --config Release  --target install

		cd ..	

	elif [ "$TYPE" == "android" ] ; then

		source $APOTHECARY_DIR/android_configure.sh $ABI cmake

		mkdir -p "build_${TYPE}_${ABI}"
		cd "build_${TYPE}_${ABI}"
		rm -f CMakeCache.txt *.a *.o
			cmake .. ${DEFINES} \
				-DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 " \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
				-DCMAKE_C_COMPILER=${CC} \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_BUILD_TYPE=Release \
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
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..
	elif [ "$TYPE" == "linux64" ] || [ "$TYPE" == "msys2" ]; then
			mkdir -p build_$TYPE
	    cd build_$TYPE
	    rm -f CMakeCache.txt *.a *.o
	    cmake .. \
	    	${DEFINES} \
	    	-DCMAKE_SYSTEM_NAME=$TYPE \
        	-DCMAKE_SYSTEM_PROCESSOR=$ABI \
				-DCMAKE_CXX_STANDARD_REQUIRED=ON \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++${CPP_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
				-DCMAKE_CXX_EXTENSIONS=OFF \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include \
				cmake --build . --target install --config Release
	    cd ..
	elif [ "$TYPE" == "linuxaarch64" ]; then
      source ../../${TYPE}_configure.sh
      mkdir -p build_$TYPE
	    cd build_$TYPE
	    rm -f CMakeCache.txt *.a *.o
	    cmake .. \
	    	${DEFINES} \
	    	-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/aarch64-linux-gnu.toolchain.cmake \
	    	-DCMAKE_SYSTEM_NAME=$TYPE \
        		-DCMAKE_SYSTEM_PROCESSOR=$ABI \
				-DCMAKE_C_STANDARD=${C_STANDARD} \
				-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
				-DCMAKE_CXX_STANDARD_REQUIRED=ON \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 -std=c++${CPP_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 -std=c${C_STANDARD} -Wno-implicit-function-declaration -frtti ${FLAG_RELEASE}" \
				-DCMAKE_CXX_EXTENSIONS=OFF \
				-DBUILD_SHARED_LIBS=OFF \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
				-DCMAKE_INSTALL_INCLUDEDIR=include \
				cmake --build . --target install --config Release
	    cd ..
	elif [ "$TYPE" == "emscripten" ]; then
		mkdir -p build_$TYPE
	    cd build_$TYPE
	    rm -f CMakeCache.txt *.a *.o *.a
	    $EMSDK/upstream/emscripten/emcmake cmake .. \
	    	${DEFINES} \
			-DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
			-DCMAKE_C_STANDARD=${C_STANDARD} \
			-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-std=c++${CPP_STANDARD} ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="-std=c${C_STANDARD} ${FLAG_RELEASE}" \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_INSTALL_PREFIX=Release \
			-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
			-DCMAKE_INSTALL_INCLUDEDIR=include \
			-DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE=. \
			-DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE=. \
			-DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE=. 
	    cmake --build . --target install --config Release
	    cd ..
	fi
		
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	mkdir -p $1/include
	. "$SECURE_SCRIPT"
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${ARCH}/Release/lib/fmt.lib" $1/lib/$TYPE/$PLATFORM/fmt.lib
		cp -RT "build_${TYPE}_${ARCH}/Release/include/" $1/include
		secure $1/lib/$TYPE/$PLATFORM/fmt.lib fmt.pkl
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libfmt.a" $1/lib/$TYPE/$PLATFORM/libfmt.a
		secure $1/lib/$TYPE/$PLATFORM/libfmt.a fmt.pkl
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include
	elif [ "$TYPE" == "android" ] ; then
		mkdir -p $1/lib/$TYPE/$ABI/
		cp -v "build_${TYPE}_${ABI}/Release/lib/libfmt.lib" $1/lib/$TYPE/$ABI/libfmt.a
		secure $1/lib/$TYPE/$ABI/libfmt.a fmt.pkl
		cp -R "build_${TYPE}_${ABI}/Release/include/" $1/include
	elif [ "$TYPE" == "emscripten" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM
		cp -v "build_${TYPE}/Release/lib/libfmt.a" $1/lib/$TYPE/$PLATFORM/libfmt.a
		cp -R "build_${TYPE}/Release/include/" $1/include
		secure $1/lib/$TYPE/$PLATFORM/libfmt.a fmt.pkl
	else
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -v "build_${TYPE}_${PLATFORM}/Release/bin/libfmt.a" $1/lib/$TYPE/$PLATFORM/libfmt.a
		secure $1/lib/$TYPE/$PLATFORM/libfmt.a fmt.pkl
		cp -R "build_${TYPE}_${PLATFORM}/Release/include/" $1/include	
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
	if [ "$TYPE" == "vs" ] ; then
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    rm -r build_${TYPE}_${ARCH}     
		fi
	elif [ "$TYPE" == "android" ] ; then
		if [ -d "build_${TYPE}_${ABI}" ]; then
			rm -r build_${TYPE}_${ABI}     
	  	fi
	elif [ "$TYPE" == "emscripten" ] ; then
		if [ -d "build_${TYPE}" ]; then
			rm -r build_${TYPE}
	  fi
	elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		if [ -d "build_${TYPE}_${PLATFORM}" ]; then
			rm -r build_${TYPE}_${PLATFORM}     
	  	fi
	else
		echoVerbose "clean not setup for $TYPE"
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "fmt" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
