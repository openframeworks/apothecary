#! /bin/bash
#
# Open Asset Import Library
# cross platform 3D model loader
# https://github.com/assimp/assimp
#
# uses CMake

# define the version
VER=5.3.1

# tools for git use
GIT_URL=
# GIT_URL=https://github.com/assimp/assimp.git
GIT_TAG=

FORMULA_TYPES=( "osx" "ios" "tvos" "android" "emscripten" "vs" )

# download the source code and unpack it into LIB_NAME
function download() {

    # stable release from source forge
    curl -LO "https://github.com/assimp/assimp/archive/v$VER.zip"
    unzip -oq "v$VER.zip"
    mv "assimp-$VER" assimp
    rm "v$VER.zip"

}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "Prepare"

    # if [ "$TYPE" == "ios" ] ; then

    #   # # patch outdated Makefile.osx provided with FreeImage, check if patch was applied first
    #   # if patch -p0 -u -N --dry-run --silent < $FORMULA_DIR/assimp.ios.patch 2>/dev/null ; then
    #   #   patch -p0 -u < $FORMULA_DIR/assimp.ios.patch
    #   # fi

    # fi
}

# executed inside the lib src dir
function build() {

    rm -f CMakeCache.txt || true

    local IOS_ARCHS
    if [[ "${TYPE}" == "tvos" ]]; then
        IOS_ARCHS="x86_64 arm64"
    elif [[ "$TYPE" == "ios" ]]; then
        IOS_ARCHS="x86_64 armv7 arm64" #armv7s
    fi

    if [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        if [[ "$TYPE" == "tvos" ]]; then
            export IOS_MIN_SDK_VER=9.0
        fi
        echo "building $TYPE | $IOS_ARCHS"
        cd ./port/iOS/
        ./build.sh --stdlib=libc++ --archs="armv7 armv7s arm64 x86_64" IOS_SDK_VERSION=$IOS_MIN_SDK_VER
        echo "--------------------"

        echo "Completed Assimp for $TYPE"
    fi

    if [ "$TYPE" == "osx" ] ; then

        # warning, assimp on github uses the ASSIMP_ prefix for CMake options ...
        # these may need to be updated for a new release
        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"

        # mkdir -p build_osx
        # cd build_osx
        # 32 bit
        cmake -G 'Unix Makefiles' $buildOpts \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER} \
        -DCMAKE_C_FLAGS="-arch arm64 -arch x86_64 -O3 -DNDEBUG -funroll-loops" \
        -DCMAKE_CXX_FLAGS="-arch arm64 -arch x86_64 -stdlib=libc++ -O3 -DNDEBUG -funroll-loops -std=c++11" .
        make assimp -j${PARALLEL_MAKE}

    elif [ "$TYPE" == "vs" ] ; then

        unset TMP
        unset TEMP
        #architecture selection inspired int he tess formula, shouldn't build both architectures in the same run?
        echo "building $TYPE | $ARCH | $VS_VER"
        echo "--------------------"

        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0
            -DLIBRARY_SUFFIX=${ARCH}"
        local generatorName="Visual Studio "
        generatorName+=$VS_VER
        if [ $ARCH == 32 ] ; then
            mkdir -p build_vs_32
            cd build_vs_32
            cmake .. -G "$generatorName" $buildOpts
            vs-build "Assimp.sln" build "Release|Win32"
        elif [ $ARCH == 64 ] ; then
            mkdir -p build_vs_64
            cd build_vs_64
            if [ $VS_VER == 15 ] ; then
                generatorName+=' Win64'
                cmake .. -G "$generatorName" $buildOpts
            else
                cmake .. -G "$generatorName" -A x64 $buildOpts
            fi
            vs-build "Assimp.sln" build "Release|x64"
            vs-build "Assimp.sln" build "Debug|x64"
        fi
        cd ..
        #cleanup to not fail if the other platform is called
        rm -f CMakeCache.txt
        echo "--------------------"
        echo "Completed Assimp for $TYPE | $ARCH | $VS_VER"


    elif [ "$TYPE" == "msys2" ] ; then
        echoWarning "TODO: msys2 build"

    elif [ "$TYPE" == "android" ] ; then

        source ../../android_configure.sh $ABI
								
        #stuff to remove when we upgrade android
        #android complains about abs being ambigious - pfffft
        sed -i -e 's/abs(/(int)fabs(/g' include/assimp/Hash.h
        sed -i -e '/string_view/d' code/AssetLib/Obj/ObjFileParser.cpp

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
                -DANDROID_STL=c++_static
                -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM
                -DCMAKE_INSTALL_PREFIX=install"
        fi
 # -- Enabled formats: AMF 3DS AC ASE ASSBIN ASSXML B3D BVH COLLADA DXF CSM HMP IRRMESH IRR LWO LWS MD2 MD3 MD5 MDC MDL NFF NDO OFF OBJ OGRE OPENGEX PLY MS3D COB BLEND IFC XGL FBX Q3D Q3BSP RAW SIB SMD TERRAGEN 3D X X3D GLTF 3MF MMD

            # -DASSIMP_BUILD_STL_IMPORTER=0
            # -DASSIMP_BUILD_BLEND_IMPORTER=0
        rm -rf build_android
        mkdir -p build_android
        cd build_android
        cmake -G 'Unix Makefiles' $buildOpts -DCMAKE_C_FLAGS="-O3 -DNDEBUG ${CFLAGS}" -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG ${CFLAGS}" -DCMAKE_LD_FLAGS="$LDFLAGS" ..
        make assimp -j${PARALLEL_MAKE}
        cd ..

    elif [ "$TYPE" == "emscripten" ] ; then

        # warning, assimp on github uses the ASSIMP_ prefix for CMake options ...
        # these may need to be updated for a new release
        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"
        mkdir -p build_emscripten
        cd build_emscripten
        emcmake cmake -G 'Unix Makefiles' $buildOpts -DCMAKE_C_FLAGS="-O3 -DNDEBUG -pthread" -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG -pthread" ..
        emmake make assimp -j${PARALLEL_MAKE}
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


    # libs
    mkdir -p $1/lib/$TYPE
    if [ "$TYPE" == "vs" ] ; then
        if [ $ARCH == 32 ] ; then
            mkdir -p $1/lib/$TYPE/Win32
            # copy .lib and .dll artifacts
            cp -v build_vs_32/lib/Release/*.lib $1/lib/$TYPE/Win32
            # copy header files
            cp -v -r build_vs_32/include/* $1/include
        elif [ $ARCH == 64 ] ; then
            mkdir -p $1/lib/$TYPE/x64
            # copy .lib and .dll artifacts
            cp -vr build_vs_64/lib/Release $1/lib/$TYPE/x64
            cp -vr build_vs_64/lib/Debug $1/lib/$TYPE/x64
            # copy header files
            cp -v -r build_vs_64/include/* $1/include
        fi
    elif [ "$TYPE" == "osx" ] ; then
        cp -Rv lib/libassimp.a $1/lib/$TYPE/assimp.a
    elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -Rv lib/iOS/libassimp-fat.a $1/lib/$TYPE/assimp.a
        cp -Rv include/* $1/include
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -Rv build_android/include/* $1/include
        cp -Rv build_android/lib/libassimp.a $1/lib/$TYPE/$ABI/libassimp.a
    elif [ "$TYPE" == "emscripten" ]; then
        cp -Rv build_emscripten/include/* $1/include
        cp -Rv build_emscripten/lib/libassimp.a $1/lib/$TYPE/libassimp.a
    fi

    # copy license files
    rm -rf $1/license # remove any older files if exists
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {

    if [ "$TYPE" == "vs" ] ; then
        if [ $ARCH == 32 ] ; then
            vs-clean "build_vs_32/Assimp.sln";
        elif [ $ARCH == 64 ] ; then
            vs-clean "build_vs_64/Assimp.sln";
        fi
        rm -f CMakeCache.txt
        echo "Assimp VS | $TYPE | $ARCH cleaned"

    elif [ "$TYPE" == "android" ] ; then
        echoWarning "TODO: clean android"

    else
        make clean
        make rebuild_cache
        rm -f CMakeCache.txt
    fi
}
