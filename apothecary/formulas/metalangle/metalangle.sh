#!/usr/bin/env bash
#
# metalangle
# https://github.com/kakashidinho/metalangle.git

FORMULA_TYPES=( "osx" "ios" "watchos" "catos" "xros" "tvos" )
FORMULA_DEPENDS=( )

# define the version
VER=1.0
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/kakashidinho/metalangle.git
GIT_ORIGIN=https://github.com/google/metalangle.git
GIT_TAG=v$VER

SCHEME=MetalANGLE
ARCHS=~/Library/Developer/Xcode/Archives

# download the source code and unpack it into LIB_NAME
function download() {
	. "$DOWNLOADER_SCRIPT"
    git clone ${GIT_URL}


}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	echo

	 echo "Fetch Subdependancies"
    ./ios/xcode/fetchDependencies.sh

	cp -r $FORMULA_DIR/metalangle/ ./

	mkdir -p "src/id"
	./src/commit_id.sh gen /Users/one/SOURCE/apothecary/apothecary/build/metalangle/src ./src/id/commit.h


	# cp -r $FORMULA_DIR/metalangle/CMakeLists.txt metalangle/CMakeLists.txt
}

# executed inside the lib src dir
function build() {
    echo

    LIBS_ROOT=$(realpath $LIBS_DIR)

	DEFS="
		    -DCMAKE_C_STANDARD=${C_STANDARD} \
		    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
		    -DBUILD_SHARED_LIBS=OFF"

	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o

		cmake .. ${DEFS} \
				-DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
				-DPLATFORM=$PLATFORM \
				-DCMAKE_INSTALL_PREFIX=Release \
				-DCMAKE_BUILD_TYPE=Release \
				-DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
				-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
				-DENABLE_BITCODE=OFF \
				-DENABLE_ARC=ON \
				-DENABLE_VISIBILITY=OFF \
				-DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
				-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
		cmake --build . --config Release --target install
		cd ..
	fi
    # if [ "$TYPE" == "ios" ] ; then
	# 	xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/iOSDevice.xcarchive -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project OpenGLES.xcodeproj
	# elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
	# 	echo
	# fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	echo
	# headers
	mkdir -p $1/include
    rm -rf $1/include/*
    cp -Rv include/* $1/include

    . "$SECURE_SCRIPT"
    # libs
    mkdir -p $1/lib/$TYPE
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        cp -v -r build_${TYPE}_${PLATFORM}/Release/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${PLATFORM}/Release/lib/libmetalangle.a $1/lib/$TYPE/$PLATFORM/libmetalangle.a
        secure $1/lib/$TYPE/$PLATFORM/libmetalangle.a metalangle.pkl
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        rm -f build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "metalangle" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
