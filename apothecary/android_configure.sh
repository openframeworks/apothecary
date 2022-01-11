#!/usr/bin/env bash
export ABI=$1

if  [ -z "$2" ]; then
    export BUILD_SYSTEM=make
    echo "android_configure: make config"
else
    export BUILD_SYSTEM=$2 #make / cmake
    echo "android_configure: cmake config"
fi

if [ "$(uname)" = "Darwin" ]; then
    export HOST_PLATFORM=darwin-x86_64
    export ANDROID_TOOLHOST="linux-android"
elif [ "$(uname)" == "windows" ]; then
    export ANDROID_HOST="windows-x86_64"
    export ANDROID_TOOLHOST="windows-android"
else
    export HOST_PLATFORM=linux-x86_64
    export ANDROID_TOOLHOST="linux-android"
fi
export LIBSPATH=android/$ABI
export NDK_PLATFORM=$ANDROID_PLATFORM
export TOOLCHAIN_VERSION=4.9
export CLANG_VERSION=
export ANDROID_NDK_HOME=$NDK_ROOT


export TOOLCHAIN_TYPE=llvm${CLANG_VERSION}
export TOOLCHAIN=${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}

if [ "$NDK_VERSION_MAJOR" = "23" ]; then
    export SYSROOT="${TOOLCHAIN}/sysroot"
    echo "NDK_VESION_MAJOR: ${NDK_VERSION_MAJOR}"
fi

echo "NDK_PLATFORM: $ANDROID_PLATFORM"
echo "ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
echo "SYSROOT: $SYSROOT"

if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
    export MACHINE=armv7
    export ANDROID_PREFIX=arm-${ANDROID_TOOLHOST}eabi
    export ANDROID_POSTFIX=${ANDROID_PREFIX}
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}

elif [ "$ABI" = "arm64-v8a" ]; then
    export MACHINE=arm64
    export ANDROID_PREFIX=aarch64-${ANDROID_TOOLHOST}
    export ANDROID_POSTFIX=${ANDROID_PREFIX}
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}

elif [ "$ABI" = "x86" ]; then
    export MACHINE=i686
    export ANDROID_PREFIX=x86
    export ANDROID_POSTFIX=i686-${ANDROID_TOOLHOST}
    export GCC_TOOLCHAIN=x86-${TOOLCHAIN_VERSION}

elif [ "$ABI" = "x86_64" ]; then
    export MACHINE=x86_64
    export ANDROID_PREFIX=x86_64
    export ANDROID_POSTFIX=x86_64-${ANDROID_TOOLHOST}
    export GCC_TOOLCHAIN=x86_64-${TOOLCHAIN_VERSION}

fi
export TARGET_HOST=$ANDROID_POSTFIX
export TARGET=${ANDROID_POSTFIX}
if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
    export TARGET=armv7a-${ANDROID_TOOLHOST}eabi #special fix for armv7
fi

if [ "$NDK_VERSION_MAJOR" = "22" ]; then
    export LIB_SYSROOT="${SYSROOT}/usr/lib/$ANDROID_PLATFORM/arch-arm"
fi


export ANDROID_CMAKE_TOOLCHAIN=${NDK_ROOT}/build/cmake/android.toolchain.cmake

export TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}/bin
export DEEP_TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}/sysroot/usr/lib/$ANDROID_POSTFIX/$ANDROID_API
export GCC_TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${GCC_TOOLCHAIN}/prebuilt/${HOST_PLATFORM}
export TOOLCHAIN_INCLUDE_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}/sysroot/usr/include
export TOOLCHAIN_LOCAL_INCLUDE_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN_TYPE}/prebuilt/${HOST_PLATFORM}/sysroot/usr/local/include
export PATH=${PATH}:${TOOLCHAIN_PATH}
# Configure and build.
export AR=$TOOLCHAIN/bin/llvm-ar
export CC=$TOOLCHAIN/bin/${TARGET}${ANDROID_API}-clang
export AS=$CC
export CXX=$TOOLCHAIN/bin/${TARGET}${ANDROID_API}-clang++
export LD=$TOOLCHAIN/bin/ld
export RANLIB=$TOOLCHAIN/bin/llvm-ranlib
export STRIP=$TOOLCHAIN/bin/llvm-strip


if [ "$BUILD_SYSTEM" = "cmake" ]; then
    export ANDROID_FIX_API="" # defined by default in cmake
    export MAKE_TARGET=""
    export MAKE_INCLUDES_CFLAGS=""
    export MAKE_INCLUDES_CPPFLAGS=""
    export OPTIMISE=""
else 
    export OPTIMISE="-Oz "
    export ANDROID_FIX_API="-D__ANDROID__ -D__ANDROID_API__=${ANDROID_API}" # fixes missing stderr/api calls when linking
    export MAKE_INCLUDES_CFLAGS=" -I${SYSROOT}/usr/include/${ANDROID_POSTFIX} -fPIC -fPIE -frtti"
    export MAKE_INCLUDES_CPPFLAGS="-stdlib=libc++ -I${SYSROOT}/usr/include/ -I${SYSROOT}/usr/include/${ANDROID_POSTFIX} -I${NDK_ROOT}/sources/android/support/include -I${NDK_ROOT}/sources/android/cpufeatures -I${TOOLCHAIN_INCLUDE_PATH} -I${TOOLCHAIN_INCLUDE_PATH}/${ANDROID_POSTFIX} -I${TOOLCHAIN_LOCAL_INCLUDE_PATH} -frtti"
    if [ "$ABI" = "armeabi-v7a" ]; then
        export MAKE_TARGET="-target armv7-linux-androideabi -mfloat-abi=softfp -mfloat-abi=softfp -march=armv7-a "
    elif [ $ABI = "arm64-v8a" ]; then
        export MAKE_TARGET="-target aarch64-linux-android" 
    elif [ "$ABI" = "x86-64" ]; then
        export MAKE_TARGET="-target x86_64-linux-android "
    elif [ "$ABI" = "x86" ]; then
        export MAKE_TARGET="-target i686-linux-android -mfpmath=sse  -fno-stack-protector -msse3 -mstackrealign " 
    fi
fi




export CFLAGS="${OPTIMISE} ${ANDROID_FIX_API} -std=c17 -fno-short-enums ${MAKE_INCLUDES_CFLAGS}" 
export CPPFLAGS="${OPTIMISE} ${ANDROID_FIX_API} ${MAKE_INCLUDES_CPPFLAGS}" #-I${NDK_ROOT}/sources/cxx-stl/llvm-libc++/include"  #-DANDROID_STL=c++_static -  #
export CXXFLAGS="-std=c++17"
#export CPPFLAGS="-v" # verbose output to test issues

export LDFLAGS="-pie -L${NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${ABI} -L$DEEP_TOOLCHAIN_PATH "
export LIBS="" #"-lz -lc -lm -ldl -lgcc -lc++ -lc++abi"
#export LDFLAGS="$LDFLAGS $LIBS"
# -ldl -lm -lc "
export ANDROID_SYSROOT=${SYSROOT}

echo "Toolchain: ${TOOLCHAIN_INCLUDE_PATH}"

export PATH=${TOOLCHAIN}:$PATH

echo "AR: ${AR}"
if [ "$ABI" = "armeabi-v7a" ]; then
    export CFLAGS="$CFLAGS $MAKE_TARGET "
    export CPPFLAGS="$CPPFLAGS $MAKE_TARGET  "
    #export CPPFLAGS="$CPPFLAGS -isystem ${SYSROOT}/usr/include/arm-linux-androideabi"
    export LDFLAGS="$LDFLAGS $MAKE_TARGET -march=armv7-a -mfloat-abi=softfp -Wl,--fix-cortex-a8 -Wl,--no-undefined"
elif [ $ABI = "arm64-v8a" ]; then
    export CFLAGS="$CFLAGS $MAKE_TARGET " 
    export CPPFLAGS="$CPPFLAGS $MAKE_TARGET"
    #export CPPFLAGS="$CPPFLAGS -isystem ${SYSROOT}/usr/include/aarch64-linux-android" # for ASM includes
    export LDFLAGS="$LDFLAGS"
elif [ "$ABI" = "x86-64" ]; then
    export CFLAGS="$CFLAGS $MAKE_TARGET"
    export CPPFLAGS="$CPPFLAGS $MAKE_TARGET "
    #export CPPFLAGS="$CPPFLAGS -isystem ${SYSROOT}/usr/include/x86_64-linux-android" # for ASM includes
    export LDFLAGS="$LDFLAGS $MAKE_TARGET -Wl,--fix-cortex-a8 -shared -Wl,--no-undefined"
elif [ "$ABI" = "x86" ]; then
    export CFLAGS="$CFLAGS $MAKE_TARGET"  #march=i686  -target i686-linux-android 
    export CPPFLAGS="$CPPFLAGS $MAKE_TARGET" #  -target i686-none-linux-android
    #export CPPFLAGS="$CPPFLAGS -isystem ${SYSROOT}/usr/include/i686-linux-android"
    export LDFLAGS="$LDFLAGS  "
fi

export CXXFLAGS="$CXXFLAGS $CPPFLAGS"
