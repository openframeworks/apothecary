#! /bin/bash
#
# Open Asset Import Library
# cross platform 3D model loader
# https://github.com/assimp/assimp
#
# uses CMake

FORMULA_TYPES=( "osx" "ios" "watchos" "catos" "xros" "tvos" "android" "emscripten" "vs" )
FORMULA_DEPENDS=( "zlib" )

# define the version
VER=5.3.1
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://github.com/assimp/assimp
GIT_TAG=

# download the source code and unpack it into LIB_NAME
function download() {

    echo "Downloading Assimp $VER"
    # stable release from GitHub
    echo "From $GIT_URL/archive/refs/tags/v$VER.zip"
    curl -LO "$GIT_URL/archive/refs/tags/v$VER.zip"

    unzip -oq "v$VER.zip"
    mv "assimp-$VER" assimp
    rm "v$VER.zip"

}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "Prepare"

    apothecaryDependencies download
    
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib
   
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        echo "building $TYPE | $ARCH $PLATFORM"
        echo "--------------------" 
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"   

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt || true
        find ./ -name "*.o" -type f -delete
        DEFS="
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0
            -DASSIMP_BUILD_ZLIB=OFF 
            -DASSIMP_WARNINGS_AS_ERRORS=OFF"

        cmake .. ${DEFS} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} 

        cmake --build . --config Release
        cd ..      
        #cleanup to not fail if the other platform is called
        rm -f CMakeCache.txt

    elif [ "$TYPE" == "vs" ] ; then
        
        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"     
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/${PLATFORM}/zlib.lib"   

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true
        DEFS="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=ON \
            -DASSIMP_BUILD_TESTS=0 \
            -DASSIMP_BUILD_SAMPLES=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DASSIMP_WARNINGS_AS_ERRORS=OFF \
            -DBUILD_WITH_STATIC_CRT=OFF"

        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build . --config Release

        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build . --config Debug 
        rm -f CMakeCache.txt || true
        cd .. 
        echo "--------------------"
        echo "Completed Assimp for $TYPE | $ARCH | $VS_VER"

    elif [ "$TYPE" == "msys2" ] ; then
        echoWarning "TODO: msys2 build"

    elif [ "$TYPE" == "android" ] ; then

        ANDROID_API=24
        ANDROID_PLATFORM=android-${ANDROID_API}

        source ../../android_configure.sh $ABI cmake

								
        #stuff to remove when we upgrade android
        #android complains about abs being ambigious - pfffft
        #sed -i -e 's/abs(/(int)fabs(/g' include/assimp/Hash.h
        #sed -i -e '/string_view/d' code/AssetLib/Obj/ObjFileParser.cpp

        if [ "$ABI" == "armeabi-v7a" ]; then
            export HOST=armv7a-linux-android
            local buildOpts="
                -DBUILD_SHARED_LIBS=OFF
                -DASSIMP_BUILD_TESTS=0
                -DASSIMP_BUILD_SAMPLES=0
                -DASSIMP_BUILD_3MF_IMPORTER=0
                -DASSIMP_BUILD_ZLIB=1
                -DANDROID_NDK=$NDK_ROOT
                -DCMAKE_TOOLCHAIN_FILE=$ANDROID_CMAKE_TOOLCHAIN
                -DCMAKE_BUILD_TYPE=Release
                -DANDROID_ABI=$ABI
                -DCMAKE_ANDROID_ARCH_ABI=$ABI 
                -DANDROID_STL=c++_static
                -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM
                -DANDROID_FORCE_ARM_BUILD=TRUE
                -DCMAKE_INSTALL_PREFIX=install"

        elif [ "$ABI" == "arm64-v8a" ]; then
            export HOST=aarch64-linux-android
            local buildOpts="
                -DBUILD_SHARED_LIBS=OFF
                -DASSIMP_BUILD_TESTS=0
                -DASSIMP_BUILD_SAMPLES=0
                -DASSIMP_BUILD_3MF_IMPORTER=0
                -DASSIMP_BUILD_ZLIB=1
                -DANDROID_NDK=$NDK_ROOT
                -DCMAKE_TOOLCHAIN_FILE=$ANDROID_CMAKE_TOOLCHAIN
                -DCMAKE_BUILD_TYPE=Release
                -DANDROID_ABI=$ABI
                -DCMAKE_ANDROID_ARCH_ABI=$ABI 
                -DANDROID_STL=c++_static
                -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM
                -DANDROID_FORCE_ARM_BUILD=TRUE
                -DCMAKE_INSTALL_PREFIX=install"
        elif [ "$ABI" == "x86" ]; then
            export HOST=x86-linux-android
            local buildOpts="
                -DBUILD_SHARED_LIBS=OFF
                -DASSIMP_BUILD_TESTS=0
                -DASSIMP_BUILD_SAMPLES=0
                -DASSIMP_BUILD_3MF_IMPORTER=0
                -DASSIMP_BUILD_ZLIB=1
                -DANDROID_NDK=$NDK_ROOT
                -DCMAKE_TOOLCHAIN_FILE=$ANDROID_CMAKE_TOOLCHAIN
                -DCMAKE_BUILD_TYPE=Release
                -DANDROID_ABI=$ABI
                -DCMAKE_ANDROID_ARCH_ABI=$ABI 
                -DANDROID_STL=c++_static
                -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM
                -DCMAKE_INSTALL_PREFIX=install"
        elif [ "$ABI" == "x86_64" ]; then
            export HOST=x86_64-linux-android
            local buildOpts="
                -DBUILD_SHARED_LIBS=OFF
                -DASSIMP_BUILD_TESTS=0
                -DASSIMP_BUILD_SAMPLES=0
                -DASSIMP_BUILD_3MF_IMPORTER=0
                -DASSIMP_BUILD_ZLIB=1
                -DANDROID_NDK=$NDK_ROOT
                -DCMAKE_TOOLCHAIN_FILE=$ANDROID_CMAKE_TOOLCHAIN
                -DCMAKE_BUILD_TYPE=Release
                -DANDROID_ABI=$ABI
                -DCMAKE_ANDROID_ARCH_ABI=$ABI
                -DANDROID_STL=c++_static
                -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM
                -DCMAKE_INSTALL_PREFIX=install"
        fi
        
        
        
        mkdir -p "build_${TYPE}_${ABI}"
        cd "build_${TYPE}_${ABI}"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true
        export CFLAGS=""
        export CPPFLAGS=""
        export LDFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
        
        cmake -S .. -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
            $buildOpts \
            -DCMAKE_C_COMPILER=${CC} \
            -DASSIMP_ANDROID_JNIIOSYSTEM=OFF \
            -DANDROID_STL=c++_shared \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_C_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_COMPILER_AR=${AR} \
            -DCMAKE_C_COMPILER_AR=${AR} \
            -DAI_CONFIG_ANDROID_JNI_ASSIMP_MANAGER_SUPPORT=OFF \
            -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -O3 -fPIC -Wno-implicit-function-declaration" \
            -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -O3 -fPIC -Wno-implicit-function-declaration" \
            -DCMAKE_EXE_LINKER_FLAGS=" -Wl,--hash-style=both" \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--hash-style=both" \
            -DCMAKE_MODULE_LINKER_FLAGS=" -Wl,--hash-style=both" \
            -DCMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
            -DCMAKE_C_STANDARD_LIBRARIES=${LIBS} \
            -DCMAKE_STATIC_LINKER_FLAGS="${LDFLAGS} ${NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${ABI}/libc++_shared.so ${NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${ABI}/libc++abi.a " \
            -DANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DANDROID_TOOLCHAIN=clang++ \
            -DBUILD_SHARED_LIBS=OFF \
            -DASSIMP_BUILD_STATIC_LIB=1 \
            -DASSIMP_BUILD_TESTS=0 \
            -DASSIMP_BUILD_SAMPLES=0 \
            -DASSIMP_BUILD_STL_IMPORTER=0 \
            -DASSIMP_BUILD_BLEND_IMPORTER=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1 \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DCMAKE_BUILD_TYPE=Release \
            -DANDROID_ABI=$ABI \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DANDROID_PLATFORM=$ANDROID_PLATFORM \
            -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM \
            -DCMAKE_INSTALL_PREFIX=install \
            -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="build_$ABI" \
            -G 'Unix Makefiles' .
        make clean
        make -j${PARALLEL_MAKE} VERBOSE=1
        cd ..
    
    elif [ "$TYPE" == "emscripten" ] ; then
    
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"
        # warning, assimp on github uses the ASSIMP_ prefix for CMake options ...
        # these may need to be updated for a new release
        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"
        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt *.a *.o *.a *.js
        rm -f CMakeCache.txt || true
        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B . \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            $buildOpts \
            -DCMAKE_C_FLAGS="-DNDEBUG -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE}" \
            -DCMAKE_CXX_FLAGS="-DNDEBUG -I${ZLIB_INCLUDE_DIR} ${FLAG_RELEASE}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DASSIMP_BUILD_STATIC_LIB=1 \
            -DASSIMP_BUILD_STL_IMPORTER=0 \
            -DASSIMP_BUILD_BLEND_IMPORTER=0 \
            -DASSIMP_BUILD_3MF_IMPORTER=0 \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1 \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DASSIMP_BUILD_ZLIB=OFF \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        $EMSDK/upstream/emscripten/emmake make
        $EMSDK/upstream/emscripten/emmake make install
        # cmake --build . --config Release
        cd ..

    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -p $1/include
    rm -rf $1/include/assimp
    rm -rf $1/include/*
    cp -Rv include/* $1/include

    . "$SECURE_SCRIPT"
    # libs
    mkdir -p $1/lib/$TYPE
    if [ "$TYPE" == "vs" ] ; then            
        cp -v -r build_${TYPE}_${PLATFORM}/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        mkdir -p $1/lib/$TYPE/$PLATFORM/Debug
        mkdir -p $1/lib/$TYPE/$PLATFORM/Release
        cp -v "build_${TYPE}_${PLATFORM}/bin/Release/assimp-vc${VC_VERSION}-mt.dll" $1/lib/$TYPE/$PLATFORM/Release/assimp-vc${VC_VERSION}-mt.dll
        cp -v "build_${TYPE}_${PLATFORM}/bin/Debug/assimp-vc${VC_VERSION}-mtd.dll" $1/lib/$TYPE/$PLATFORM/Debug/assimp-vc${VC_VERSION}-mtd.dll
        cp -v "build_${TYPE}_${PLATFORM}/lib/Release/assimp-vc${VC_VERSION}-mt.lib" $1/lib/$TYPE/$PLATFORM/Release/libassimp.lib 
        cp -v "build_${TYPE}_${PLATFORM}/lib/Debug/assimp-vc${VC_VERSION}-mtd.lib" $1/lib/$TYPE/$PLATFORM/Debug/libassimpD.lib
        secure $1/lib/$TYPE/$PLATFORM/libassimp.a assimp.pkl
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        cp -v -r build_${TYPE}_${PLATFORM}/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv build_${TYPE}_${PLATFORM}/lib/libassimp.a $1/lib/$TYPE/$PLATFORM/assimp.a
        secure $1/lib/$TYPE/$PLATFORM/assimp.a assimp.pkl
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -Rv build_${TYPE}_${ABI}/include/* $1/include
        cp -Rv build_${TYPE}_${ABI}/lib/libassimp.a $1/lib/$TYPE/$ABI/libassimp.a
        secure $1/lib/$TYPE/$PLATFORM/libassimp.a assimp.pkl
    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/lib/${TYPE}/${PLATFORM}
        cp -Rv build_${TYPE}_${PLATFORM}/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/lib/libassimp.a" $1/lib/$TYPE/${PLATFORM}/libassimp.a
        secure $1/lib/$TYPE/${PLATFORM}/libassimp.a assimp.pkl
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

    if [ "$TYPE" == "vs" ] ; then
        rm -f build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt
        echo "Assimp VS | $TYPE | $ARCH cleaned"

    elif [ "$TYPE" == "android" ] ; then
        if [ -d "build" ]; then
            cd  "build_${TYPE}_${ABI}"
            make clean
            cd ..
        fi
        rm -f CMakeCache.txt  2> /dev/null

    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        rm -f build_${TYPE}_${PLATFORM}
        rm -f CMakeCache.txt
    else
        make clean
        make rebuild_cache
        rm -f CMakeCache.txt 2> /dev/null
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "assimp" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
