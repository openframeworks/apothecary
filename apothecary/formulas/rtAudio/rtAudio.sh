#!/usr/bin/env bash
#
# RtAudio
# RealTime Audio input/output across Linux, Macintosh OS-X and Windows
# http://www.music.mcgill.ca/~gary/rtaudio/
#
# uses an autotools build system

FORMULA_TYPES=( "osx" "vs" )

#FORMULA_DEPENDS=( "pkg-config" )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
#FORMULA_DEPENDS_MANUAL=1

# define the version
VER=6.0.1

# tools for git use
GIT_URL=https://github.com/thestk/rtaudio
GIT_TAG=master
URL=https://www.music.mcgill.ca/~gary/rtaudio/release/

# download the source code and unpack it into LIB_NAME
function download() {
	#curl -O https://www.music.mcgill.ca/~gary/rtaudio/release/rtaudio-$VER.tar.gz
	. "$DOWNLOADER_SCRIPT"
	downloader ${URL}/rtaudio-${VER}.tar.gz
	tar -xf rtaudio-${VER}.tar.gz
	mv rtaudio-${VER} rtAudio
	rm rtaudio-${VER}.tar.gz
}

# # prepare the build environment, executed inside the lib src dir
# function prepare() {
# 	# nothing here
# }

# executed inside the lib src dir
function build() {

	# The ./configure / MAKEFILE sequence is broken for OSX, making it
	# impossible to create universal libs in one pass.  As a result, we compile
	# the project manually according to the author's page:
	# https://www.music.mcgill.ca/~gary/rtaudio/compiling.html

	if [ "$TYPE" == "osx" ] ; then
  #       rm -f librtaudio.a
  #       rm -f librtaudio-x86_64

		# # Compile the program
		# /usr/bin/g++ -O2 \
		# 			 -Wall \
		# 			 -fPIC \
		# 			 -stdlib=libc++ \
		# 			 -arch arm64 -arch x86_64 \
		# 			 -Iinclude \
		# 			 -DHAVE_GETTIMEOFDAY \
		# 			 -D__MACOSX_CORE__ \
		# 			 -mmacosx-version-min=${OSX_MIN_SDK_VER} \
		# 			 -c RtAudio.cpp \
		# 			 -o RtAudio.o

		# /usr/bin/ar ruv librtaudio.a RtAudio.o
		# /usr/bin/ranlib librtaudio.a

		mkdir -p build
		cd build
		export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		export LDFLAGS="-arch arm64 -arch x86_64"
    
		cmake .. -G "Unix Makefiles" \
			-DCMAKE_CXX_STANDARD=11 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSION=OFF \
			-DCMAKE_CXX_FLAGS="-fPIC ${CFLAGS}" \
			-DCMAKE_C_FLAGS="-fPIC ${CFLAGS}" \
			-DRTAUDIO_BUILD_SHARED_LIBS=OFF \
			-DRTAUDIO_API_ASIO=OFF \
			-DBUILD_TESTING=OFF
		make
		cd ..

		#/usr/bin/g++ -O2 \
		#			 -Wall \
		#			 -fPIC \
		#			 -stdlib=libc++ \
		#			 -arch x86_64 \
		#			 -Iinclude \
		#			 -DHAVE_GETTIMEOFDAY \
		#			 -D__MACOSX_CORE__ \
		#			 -c RtAudio.cpp \
		#			 -o RtAudio.o

		#/usr/bin/ar ruv librtaudio-x86_64.a RtAudio.o
		#/usr/bin/ranlib librtaudio-x86_64.a

		#lipo -c librtaudio.a librtaudio-x86_64.a -o librtaudio.a

	elif [ "$TYPE" == "vs" ] ; then
		echo "building rtAudio $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
    echo "--------------------"
    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
    mkdir -p "build_${TYPE}_${ARCH}"
    cd "build_${TYPE}_${ARCH}"
    DEFS="-DLIBRARY_SUFFIX=${ARCH} \
        -DCMAKE_C_STANDARD=17 \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DAUDIO_WINDOWS_WASAPI=ON \
        -DAUDIO_WINDOWS_DS=ON \
        -DAUDIO_WINDOWS_ASIO=ON \
        -DBUILD_WITH_STATIC_CRT=OFF 
        "         
    cmake .. ${DEFS} \
        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_RELEASE} ${VS_C_FLAGS} ${EXCEPTION_FLAGS}" \
        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_RELEASE} ${VS_C_FLAGS} ${EXCEPTION_FLAGS}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -DCMAKE_INSTALL_PREFIX=Release \
        ${CMAKE_WIN_SDK} \
        ${FLAGS_RELEASE} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}"

    cmake --build . --config Release --target install

    cmake .. ${DEFS} \
        -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAGS_DEBUG} ${VS_C_FLAGS} ${EXCEPTION_FLAGS}" \
        -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1  ${FLAGS_DEBUG} ${VS_C_FLAGS} ${EXCEPTION_FLAGS}" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -DCMAKE_INSTALL_PREFIX=Debug \
        ${CMAKE_WIN_SDK} \
        ${FLAGS_RELEASE} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}"

    cmake --build . --config Debug --target install

    cd ..
	elif [ "$TYPE" == "msys2" ] ; then
		# Compile the program
		local API="--with-wasapi --with-ds " # asio as well?
		mkdir -p build
		cd build
		cmake .. -G "Unix Makefiles" \
			-DAUDIO_WINDOWS_WASAPI=ON \
			-DAUDIO_WINDOWS_DS=ON \
			-DAUDIO_WINDOWS_ASIO=ON \
			-DBUILD_TESTING=OFF
		make
	fi

	# clean up env vars
	# unset PKG_CONFIG PKG_CONFIG_PATH
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -v RtAudio.h $1/include
	#cp -v RtError.h $1/include #no longer a part of rtAudio

	# libs
	mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		cp -Rv build_${TYPE}_${ARCH}/Release/include/rtaudio/* $1/include/
    	cp -vf "build_${TYPE}_${ARCH}/Release/lib/rtaudio.lib" $1/lib/$TYPE/$PLATFORM/rtaudio.lib
    	cp -vf "build_${TYPE}_${ARCH}/Debug/lib/rtaudiod.lib" $1/lib/$TYPE/$PLATFORM/rtaudioD.lib
	elif [ "$TYPE" == "msys2" ] ; then
		cd build
		ls
		cd ../
		cp -v build/librtaudio.dll.a $1/lib/$TYPE/librtaudio.dll.a

	elif [ "$TYPE" == "osx" ] ; then
		cp -v build/librtaudio.a $1/lib/$TYPE/rtaudio.a
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
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	else
		make clean
	fi

	# manually clean dependencies
	#apothecaryDependencies clean
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "rtaudio" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "rtaudio" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
