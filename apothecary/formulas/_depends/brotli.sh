#!/usr/bin/env /bash
#
# Brotli is a generic-purpose lossless compression algorithm that compresses data using a combination of a modern variant of the LZ77 algorithm, 
#  Huffman coding and 2nd order context modeling, with a compression ratio comparable to the best currently available general-purpose compression methods.
# It is similar in speed with deflate but offers more dense compression.
# https://github.com/google/brotli

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" )
FORMULA_DEPENDS=( )

# define the version
VER=1.1.0
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/google/brotli
GIT_TAG=v$VER

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
  LIBS_ROOT=$(realpath $LIBS_DIR)
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
          -DCMAKE_C_STANDARD=${C_STANDARD} \
          -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
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
          -DBROTLI_DISABLE_TESTS=ON \
          -DBROTLI_BUILD_TOOLS=OFF \
          -DBROTLI_BUNDLED_MODE=OFF \
          -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
          -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
          -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
          -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" 

      cmake --build . --config Release --target install
     	cd ..      
      rm -f CMakeCache.txt
  elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o 
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=Release \
        -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
        -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_STANDARD=${C_STANDARD} \
        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
        -DCMAKE_INSTALL_PREFIX=Release \
        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
        -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_INSTALL_LIBDIR=lib \
        -DCMAKE_INSTALL_BINARY_DIR=lib \
        -DCMAKE_INSTALL_FULL_LIBDIR=lib \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -DPLATFORM=$PLATFORM \
        -DENABLE_BITCODE=OFF \
        -DBROTLI_DISABLE_TESTS=ON \
        -DBROTLI_BUILD_TOOLS=OFF \
        -DBROTLI_BUNDLED_MODE=OFF \
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
  mkdir -p $1/include 
  . "$SECURE_SCRIPT"
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    mkdir -p $1/lib/$TYPE/$PLATFORM/
    cp -v -r c/include/* $1/include
    cp -v "build_${TYPE}_${PLATFORM}/"*.a $1/lib/$TYPE/$PLATFORM/
    secure $1/lib/$TYPE/$PLATFORM/libbrotlidec.a brotli.pkl

    cp -vR "build_${TYPE}_${PLATFORM}/libbrotlicommon.pc" $1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc
    cp -vR "build_${TYPE}_${PLATFORM}/libbrotlidec.pc" $1/lib/$TYPE/$PLATFORM/libbrotlidec.pc
    cp -vR "build_${TYPE}_${PLATFORM}/libbrotlienc.pc" $1/lib/$TYPE/$PLATFORM/libbrotlienc.pc
    
    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"

    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"

    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
	elif [ "$TYPE" == "vs" ] ; then
		cp -v -r c/include/* $1/include
    mkdir -p $1/lib/$TYPE/$PLATFORM/
    cp -v "build_${TYPE}_${PLATFORM}/Release/"*.lib $1/lib/$TYPE/$PLATFORM/
    secure $1/lib/$TYPE/$PLATFORM/brotlidec.lib brotli.pkl

    cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlicommon.pc" $1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc
    cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlidec.pc" $1/lib/$TYPE/$PLATFORM/libbrotlidec.pc
    cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libbrotlienc.pc" $1/lib/$TYPE/$PLATFORM/libbrotlienc.pc
    
    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlicommon.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"

    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlidec.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"

    PKG_FILE="$1/lib/$TYPE/$PLATFORM/libbrotlienc.pc"
    sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
    sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
    sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
	fi

  if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
  mkdir -p $1/license
  cp -v LICENSE $1/license/
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

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "brotli" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}