#!/usr/bin/env /bash
#
# Brotli is a generic-purpose lossless compression algorithm that compresses data using a combination of a modern variant of the LZ77 algorithm, 
#  Huffman coding and 2nd order context modeling, with a compression ratio comparable to the best currently available general-purpose compression methods.
# It is similar in speed with deflate but offers more dense compression.
# https://github.com/google/brotli

# define the version
VER=1.1.0

# tools for git use
GIT_URL=https://github.com/google/brotli
GIT_TAG=v$VER

FORMULA_TYPES=( "vs" )

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
	#downloader ${GIT_URL}/archive/refs/tags/v$VER.tar.gz 
  #tar -xf v$VER.tar.gz
  #mv brotli-$VER brotli
  #rm v$VER.tar.gz
  downloader ${GIT_URL}/archive/refs/heads/master.tar.gz
  tar -xf master.tar.gz
  mv brotli-master brotli
  rm master.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: #noop
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "vs" ] ; then
			find ./ -name "*.o" -type f -delete
      echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
      echo "--------------------"
      GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"     
      mkdir -p "build_${TYPE}_${PLATFORM}"
      cd "build_${TYPE}_${PLATFORM}"
      rm -f CMakeCache.txt *.a *.o *.lib
      # if [ "$PLATFORM" == "ARM64EC" ] ; then
      #   echo "ARM64EC platform detected, exiting build function."
      #   return
      # fi

      DEFS="
          -DCMAKE_C_STANDARD=17 \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_CXX_STANDARD_REQUIRED=ON \
          -DCMAKE_CXX_EXTENSIONS=OFF \
          -DBUILD_SHARED_LIBS=OFF \
          -DBUILD_TESTING=OFF
          "
      cmake .. ${DEFS} \
          -A "${PLATFORM}" \
          ${CMAKE_WIN_SDK} \
          -G "${GENERATOR_NAME}" \
          -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=Release \
          -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
          -DCMAKE_INSTALL_LIBDIR="lib" \
          -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
          -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
          -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
          -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
          -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" 

      cmake --build . --config Release
     	cd ..      
      rm -f CMakeCache.txt
  elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o 
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=Release \
        -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
        -D BUILD_SHARED_LIBS=OFF \
        -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
        -DZLIB_BUILD_EXAMPLES=OFF \
        -DSKIP_EXAMPLE=ON \
        -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF 

     cmake --build . --config Release --target install
     cd ..
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
  mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "osx" ] ; then
		mkdir -p $1/include    
    mkdir -p $1/lib/$TYPE/$PLATFORM/
    cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/"* $1/include/
    cp -v "build_${TYPE}_${PLATFORM}/Release/lib/brotli.a" $1/lib/$TYPE/$PLATFORM/brotli.a
    . "$SECURE_SCRIPT"
    secure $1/lib/$TYPE/$PLATFORM/zlib.a 
	elif [ "$TYPE" == "vs" ] ; then
		cp -v -r c/include/* $1/include
    mkdir -p $1/lib/$TYPE/$PLATFORM/
    cp -v "build_${TYPE}_${PLATFORM}/Release/"*.lib $1/lib/$TYPE/$PLATFORM/
	fi
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        rm -r build_${TYPE}_${PLATFORM}     
    fi
  elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        rm -r build_${TYPE}_${PLATFORM}     
    fi
	else
		make uninstall
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "brotli" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    echo "load file ${SAVE_FILE}"
    if loadsave ${TYPE} "brotli" ${ARCH} ${VER} "${SAVE_FILE}"; then
      echo "The entry exists and doesn't need to be rebuilt."
      return 0;
    else
      echo "The entry doesn't exist or needs to be rebuilt."
      return 1;
    fi
}