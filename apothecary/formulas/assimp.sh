#! /bin/bash
#
# Open Asset Import Library
# cross platform 3D model loader
# https://github.com/assimp/assimp
#
# uses CMake

# define the version
VER=5.1.6

# tools for git use
GIT_URL=https://github.com/danoli3/assimp
GIT_TAG=

FORMULA_TYPES=( "osx" "ios" "tvos" "android" "emscripten" "vs" )

# download the source code and unpack it into LIB_NAME
function download() {

    echo "Downloading Assimp $VER"
    # stable release from GitHub
    curl -LO "$GIT_URL/archive/v$VER.zip"
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

   

    if [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        if [[ "$TYPE" == "tvos" ]]; then
            export IOS_MIN_SDK_VER=9.0
        fi
        echo "building $TYPE"
        cd ./port/iOS/
        ./build.sh --stdlib=libc++ --std=c++17 --archs="armv7 arm64 x86_64" IOS_SDK_VERSION=$IOS_MIN_SDK_VER
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
        if [ $VS_VER -gt 15 ] ; then
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
        else
            if [ $ARCH == 32 ] ; then
                mkdir -p build_vs_32
                cd build_vs_32
                generatorName+=' -A Win32'
                echo "generatorName $generatorName"
                cmake .. -G "$generatorName" $buildOpts
                vs-build "Assimp.sln" build "Release|Win32"
            elif [ $ARCH == 64 ] ; then
                mkdir -p build_vs_64
                cd build_vs_64
                generatorName+=' -A Win64'
                echo "generatorName $generatorName"
                cmake .. -G "$generatorName" $buildOpts
                vs-build "Assimp.sln" build "Release|x64"
            elif [ $ARCH == "ARM" ] ; then
                mkdir -p build_vs_arm
                cd build_vs_arm
                generatorName+=' -A ARM'
                echo "generatorName $generatorName"
                cmake .. -G "$generatorName" $buildOpts
                vs-build "Assimp.sln" build "Release|ARM"
            fi
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
       
        
        if [ -d "build" ]; then
            rm -R build
        fi
        
        

        mkdir -p "build"
       


        cd build
        mkdir -p "build_$ABI"
        rm -f CMakeCache.txt

        export CFLAGS=""
        export CPPFLAGS=""
        export LDFLAGS=""
        export CMAKE_LDFLAGS="$LDFLAGS"
        
        cmake .. -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake \
            -DCMAKE_C_COMPILER=${CC} \
            -DASSIMP_ANDROID_JNIIOSYSTEM=ON \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_C_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_COMPILER_AR=${AR} \
            -DCMAKE_C_COMPILER_AR=${AR} \
            -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -O3 -fPIC -Wno-implicit-function-declaration" \
            -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -O3 -fPIC -Wno-implicit-function-declaration " \
            -DCMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
            -DCMAKE_C_STANDARD_LIBRARIES=${LIBS} \
            -DCMAKE_STATIC_LINKER_FLAGS=${LDFLAGS} \
            -DANDROID_NATIVE_API_LEVEL=${ANDROID_API} \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
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
            -DANDROID_STL=c++_shared \
            -DANDROID_PLATFORM=$ANDROID_PLATFORM \
            -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM \
            -DCMAKE_INSTALL_PREFIX=install \
            -DCMAKE_RUNTIME_OUTPUT_DIRECTORY="build_$ABI" \
            -G 'Unix Makefiles' .

            # -D CMAKE_CXX_STANDARD_LIBRARIES=${LIBS} \
            # -D CMAKE_C_STANDARD_LIBRARIES=${LIBS} \
            #=-DCMAKE_MODULE_LINKER_FLAGS=${LIBS} #-DCMAKE_CXX_FLAGS="-Oz -DDEBUG $CPPFLAGS
            
        
        make -j${PARALLEL_MAKE} VERBOSE=1
        


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
        # cp -Rv lib/libIrrXML.a $1/lib/$TYPE/libIrrXML.a
    elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -Rv lib/iOS/libassimp-fat.a $1/lib/$TYPE/assimp.a
        cp -Rv include/* $1/include
    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/lib/$TYPE/$ABI/
        cp -Rv include/* $1/include
        cp -Rv build/lib/libassimp.a $1/lib/$TYPE/$ABI/libassimp.a
        #cp -Rv build_$ABI/contrib/irrXML/libIrrXML.a $1/lib/$TYPE/$ABI/libIrrXML.a  <-- included in cmake build
    elif [ "$TYPE" == "emscripten" ]; then
        cp -Rv build_emscripten/include/* $1/include
        cp -Rv build_emscripten/lib/libassimp.a $1/lib/$TYPE/libassimp.a
        cp -Rv build_emscripten/contrib/zlib/libzlibstatic.a $1/lib/$TYPE/libzlibstatic.a
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
        make clean
        make rebuild_cache
        rm -f build/*.*
        rm -f build/
        rm -f build/libassimp.a
        rm -f CMakeCache.txt

    else
        make clean
        make rebuild_cache
        rm -f CMakeCache.txt
    fi
}
