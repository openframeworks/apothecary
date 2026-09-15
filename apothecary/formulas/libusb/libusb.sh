#!/usr/bin/env bash
#
# libusb for ofxKinect needed for
# Visual Studio and OS X

FORMULA_TYPES=("osx" "vs" "linux")
FORMULA_DEPENDS=()

GIT_URL=https://github.com/libusb/libusb
GIT_TAG=v1.0.30
GIT_BRANCH_VS=master
VER=1.0.30
SHA256="2ae28adb0bb9558c86135c4e1c11b320b0805461e207a64a6e520a114094bf07"
SHA256_ZIP="543a61dbc8878435c096aec6543d51ff73f6a80743621c66ecab2ba1eb66a974"
BUILD_ID=1
DEFINES=""

URL=https://github.com/libusb/libusb/archive/refs/tags/v${VER}

# download the source code and unpack it into LIB_NAME
function download() {

    # git clone --branch ${GIT_BRANCH_VS} ${GIT_URL}
    . "$DOWNLOADER_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        downloader "${URL}.zip"
        verify_sha256 "v${VER}.zip" "$SHA256_ZIP"
        unzip v${VER}.zip
        mv libusb-${VER} libusb
    fi

    if [ "$TYPE" == "osx" ] || [ "$TYPE" == "linux" ]; then
        downloader "${URL}.tar.gz"
        verify_sha256 "v${VER}.tar.gz" "$SHA256"
        tar -xzf v${VER}.tar.gz

        mv libusb-${VER} libusb
    fi

}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    cp -f $FORMULA_DIR/CMakeLists.txt .

    if [ "$TYPE" == "vs" ] || [ "$TYPE" == "linux" ]; then
        cp -f $FORMULA_DIR/config.h.in ./config.h.in
    elif [ "$TYPE" == "osx" ]; then
        cp -f ./Xcode/config.h ./config.h
    fi
}

# executed inside the lib src dir
function build() {

    if [ "$TYPE" == "vs" ]; then

        echo "building libusb $TYPE | $ARCH | $VS_VER | vs: Visual Studio ${VS_VER_GEN} -A ${PLATFORM}"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.lib *.o
        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
	        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"
        cmake .. ${DEFS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DLIBUSB_BUILD_TESTING=OFF \
            -DLIBUSB_BUILD_EXAMPLES=OFF \
            -DLIBUSB_INSTALL_TARGETS=ON \
            -DLIBUSB_BUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            ${CMAKE_WIN_SDK} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    fi

    if [ "$TYPE" == "osx" ]; then
        # ./autogen.sh
        # CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}" ./configure --disable-shared --enable-static
        # make -j${PARALLEL_MAKE}

        GENERATOR_NAME="Xcode"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o
        DEFS="-DLIBRARY_SUFFIX=${PLATFORM} \
	        -DCMAKE_BUILD_TYPE=Release \
	        -DCMAKE_C_STANDARD=${C_STANDARD} \
	        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
	        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
	        -DCMAKE_CXX_EXTENSIONS=OFF
	        -DBUILD_SHARED_LIBS=OFF \
	        -DCMAKE_INSTALL_PREFIX=Release \
	        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
	        -DCMAKE_INSTALL_INCLUDEDIR=include"
        cmake .. ${DEFS} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -G Xcode \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DLIBUSB_BUILD_TESTING=OFF \
            -DLIBUSB_BUILD_EXAMPLES=OFF \
            -DLIBUSB_INSTALL_TARGETS=ON \
            -DLIBUSB_BUILD_SHARED_LIBS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_BUILD_TYPE=Release \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..
    fi

    if [ "$TYPE" == "linux" ]; then
        cmake -S . -B "build_${TYPE}_${PLATFORM}" \
            -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake" \
            -DCMAKE_C_STANDARD="${C_STANDARD}" \
            -DCMAKE_CXX_STANDARD="${CPP_STANDARD}" \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="build_${TYPE}_${PLATFORM}/Release" \
            -DCMAKE_INSTALL_LIBDIR=lib \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DLIBUSB_BUILD_TESTING=OFF \
            -DLIBUSB_BUILD_EXAMPLES=OFF \
            -DLIBUSB_INSTALL_TARGETS=ON \
            -DLIBUSB_BUILD_SHARED_LIBS=OFF
        cmake --build "build_${TYPE}_${PLATFORM}" -j"${PARALLEL_MAKE}" --target install
    fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -p $1/include
    cp -Rv libusb/libusb.h $1/include
    . "$SECURE_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libusb-1.0/" $1/
        #cp -f "build_${TYPE}_${PLATFORM}/Release/libusb-1.0.dll" $1/lib/$TYPE/$PLATFORM/libusb-1.0.dll
        cp -f "build_${TYPE}_${PLATFORM}/Release/libusb-1.0.lib" $1/lib/$TYPE/$PLATFORM/libusb.lib
        secure "$1/lib/$TYPE/$PLATFORM/libusb.lib" "libusb.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi
    if [ "$TYPE" == "osx" ] || [ "$TYPE" == "linux" ]; then
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/libusb-1.0/" $1/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libusb-1.0.a" $1/lib/$TYPE/$PLATFORM/libusb.a
        secure "$1/lib/$TYPE/$PLATFORM/libusb.a" "libusb.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    # copy license file
    if [ -d "$1/license" ]; then
        rm -r $1/license
    fi
    mkdir -p $1/license
    cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {

    if [ "$TYPE" == "vs" ]; then
        rm -f *.lib

    fi
    if [ "$TYPE" == "osx" ] || [ "$TYPE" == "linux" ]; then
        rm -f *.a
    fi

    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
        # Delete the folder and its contents
        rm -r build_${TYPE}_${PLATFORM}
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "libusb" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
