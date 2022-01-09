#! /bin/bash
#
# Open Asset Import Library
# cross platform 3D model loader
# https://github.com/assimp/assimp
#
# uses CMake

# define the version
VER=5.0.1

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

    # fix an issue with static libs being disabled - see issue https://github.com/assimp/assimp/issues/271
    # this could be fixed fairly soon - so see if its needed for future releases.

    if [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        echo "iOS"
    elif [ "$TYPE" == "vs" ] ; then
        #ADDED EXCEPTION, FIX DOESN'T WORK IN VS
        echo "VS"
    else
        echo "$TYPE"

        sed -i -e 's/SET ( ASSIMP_BUILD_STATIC_LIB OFF/SET ( ASSIMP_BUILD_STATIC_LIB ON/g' assimp/CMakeLists.txt
        sed -i -e 's/option ( BUILD_SHARED_LIBS "Build a shared version of the library" ON )/option ( BUILD_SHARED_LIBS "Build a shared version of the library" OFF )/g' assimp/CMakeLists.txt
    fi
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
            -DASSIMP_BUILD_STATIC_LIB=1
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1
            -DASSIMP_BUILD_STL_IMPORTER=0
            -DASSIMP_BUILD_BLEND_IMPORTER=0
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

        local buildOpts="-DASSIMP_BUILD_STATIC_LIB=1
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1
            -DASSIMP_BUILD_STL_IMPORTER=1
            -DASSIMP_BUILD_BLEND_IMPORTER=0
            -DASSIMP_BUILD_3MF_IMPORTER=0
            -DASSIMP_BUILD_ASSIMP_TOOLS=0
            -DASSIMP_BUILD_X3D_IMPORTER=0
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
            generatorName+=' Win64'
            cmake .. -G "$generatorName" $buildOpts
            vs-build "Assimp.sln" build "Release|x64"
        fi
        cd ..
        #cleanup to not fail if the other platform is called
        rm -f CMakeCache.txt
        echo "--------------------"
        echo "Completed Assimp for $TYPE | $ARCH | $VS_VER"


    elif [ "$TYPE" == "msys2" ] ; then
        echoWarning "TODO: msys2 build"

    elif [ "$TYPE" == "android" ] ; then

        source ../../android_configure.sh $ABI cmake

        # -- Enabled formats: AMF 3DS AC ASE ASSBIN ASSXML B3D BVH COLLADA DXF CSM HMP IRRMESH IRR LWO LWS MD2 MD3 MD5 MDC MDL NFF NDO OFF OBJ OGRE OPENGEX PLY MS3D COB BLEND IFC XGL FBX Q3D Q3BSP RAW SIB SMD TERRAGEN 3D X X3D GLTF 3MF MMD

        # if ["$ABI" == "arm64-v8a"  ] || "$ABI" == "armeabi-v7a" ]; then
        #     $buildOpts = "${buildOpts} -DANDROID_FORCE_ARM_BUILD=TRUE"
        # fi 
       
        
        cd ./port/AndroidJNI/
        mkdir -p "build_$ABI"
        pwd
        #cp -v ./port/AndroidJNI/CMakeLists.txt .

        #cd "./build_$ABI"
        export CMAKE_CFLAGS="$CFLAGS -fsigned-char "
        export CFLAGS=""
        #export CPPFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
        export LDFLAGS=""
        cmake -D CMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
            -D CMAKE_OSX_SYSROOT:PATH==${SYSROOT} \
            -D CMAKE_C_COMPILER==${CC} \
            -D CMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -D CMAKE_C_COMPILER_RANLIB=${RANLIB} \
            -D CMAKE_CXX_COMPILER_AR=${AR} \
            -D CMAKE_C_COMPILER_AR=${AR} \
            -D CMAKE_C_COMPILER=${CC} \
            -D CMAKE_CXX_COMPILER=${CXX} \
            -D CMAKE_C_FLAGS=${CFLAGS} \
            -D CMAKE_CXX_FLAGS=${CPPFLAGS} \
            -D ANDROID_ABI=${ABI} \
            -D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
            -D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
            -D CMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
            -D ANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
            -D ANDROID_TOOLCHAIN=clang \
            -D BUILD_SHARED_LIBS=OFF \
            -D ASSIMP_BUILD_STATIC_LIB=1 \
            -D ASSIMP_BUILD_TESTS=0 \
            -D ASSIMP_BUILD_SAMPLES=0 \
            -D ASSIMP_BUILD_STL_IMPORTER=0 \
            -D ASSIMP_BUILD_BLEND_IMPORTER=0 \
            -D ASSIMP_BUILD_3MF_IMPORTER=0 \
            -D ASSIMP_ENABLE_BOOST_WORKAROUND=1 \
            -D ANDROID_NDK=$NDK_ROOT \
            -D CMAKE_BUILD_TYPE=Release \
            -D ANDROID_STL=c++_static \
            -D ANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM \
            -D CMAKE_INSTALL_PREFIX=install \
            -D ASSIMP_ANDROID_JNIIOSYSTEM=ON \
            -G 'Unix Makefiles' .
            # -D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
            # -D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
            #=-DCMAKE_MODULE_LINKER_FLAGS=${LIBS} #-DCMAKE_CXX_FLAGS="-Oz -DDEBUG $CPPFLAGS
            
        make -j${PARALLEL_MAKE} VERBOSE=1
        cd ..

    elif [ "$TYPE" == "emscripten" ] ; then

        # warning, assimp on github uses the ASSIMP_ prefix for CMake options ...
        # these may need to be updated for a new release
        local buildOpts="
            -DBUILD_SHARED_LIBS=OFF
            -DASSIMP_BUILD_STATIC_LIB=1
            -DASSIMP_BUILD_TESTS=0
            -DASSIMP_BUILD_SAMPLES=0
            -DASSIMP_ENABLE_BOOST_WORKAROUND=1
            -DASSIMP_BUILD_STL_IMPORTER=0
            -DASSIMP_BUILD_BLEND_IMPORTER=0
            -DASSIMP_BUILD_3MF_IMPORTER=0"
        mkdir -p build_emscripten
        cd build_emscripten
        emcmake cmake -G 'Unix Makefiles' $buildOpts -DCMAKE_C_FLAGS="-O3 -DNDEBUG" -DCMAKE_CXX_FLAGS="-O3 -DNDEBUG" ..
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
            cp -v build_vs_32/code/Release/*.lib $1/lib/$TYPE/Win32
            cp -v build_vs_32/code/Release/*.dll $1/lib/$TYPE/Win32
            # copy header files
            cp -v -r build_vs_32/include/* $1/include
        elif [ $ARCH == 64 ] ; then
            mkdir -p $1/lib/$TYPE/x64
            # copy .lib and .dll artifacts
            cp -v build_vs_64/code/Release/*.lib $1/lib/$TYPE/x64
            cp -v build_vs_64/code/Release/*.dll $1/lib/$TYPE/x64
            # copy header files
            cp -v -r build_vs_64/include/* $1/include
        fi
    elif [ "$TYPE" == "osx" ] ; then
        cp -Rv lib/libassimp.a $1/lib/$TYPE/assimp.a
        cp -Rv lib/libIrrXML.a $1/lib/$TYPE/libIrrXML.a
    elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -Rv lib/iOS/libassimp-fat.a $1/lib/$TYPE/assimp.a
        cp -Rv include/* $1/include
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -Rv include/* $1/include
        cp -Rv build_$ABI/code/libassimp.a $1/lib/$TYPE/$ABI/libassimp.a
        #cp -Rv build_$ABI/contrib/irrXML/libIrrXML.a $1/lib/$TYPE/$ABI/libIrrXML.a  <-- included in cmake build
    elif [ "$TYPE" == "emscripten" ]; then
        cp -Rv build_emscripten/include/* $1/include
        cp -Rv build_emscripten/code/libassimp.a $1/lib/$TYPE/libassimp.a
        cp -Rv build_emscripten/contrib/irrXML/libIrrXML.a $1/lib/$TYPE/libIrrXML.a
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
