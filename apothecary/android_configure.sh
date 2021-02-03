#!/usr/bin/env bash
export ABI=$1
if [ "$(uname)" = "Darwin" ]; then
    export HOST_PLATFORM=darwin-x86_64
else
    export HOST_PLATFORM=linux-x86_64
fi
export LIBSPATH=android/$ABI
export NDK_PLATFORM=$ANDROID_PLATFORM
export TOOLCHAIN_VERSION=4.9
export CLANG_VERSION=
if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
    export SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-arm"
    export ANDROID_PREFIX=arm-linux-androideabi
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}
elif [ "$ABI" = "arm64-v8a" ]; then
    export SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-arm64"
    export ANDROID_PREFIX=aarch64-linux-android
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}
elif [ "$ABI" = "x86" ]; then
    export SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-x86"
    export ANDROID_PREFIX=x86-linux-android
    export GCC_TOOLCHAIN=x86-${TOOLCHAIN_VERSION}
elif [ "$ABI" = "x86_64" ]; then
    export SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-x86_64"
    export ANDROID_PREFIX=x86_64
    export GCC_TOOLCHAIN=x86-${TOOLCHAIN_VERSION}
elif [ $ABI = arm64-v8a ]; then
    export SYSROOT=${NDK_ROOT}/sysroot
    export ANDROID_PREFIX=aarch64-linux-android
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}
fi
export ANDROID_CMAKE_TOOLCHAIN=${NDK_ROOT}/build/cmake/android.toolchain.cmake
export TOOLCHAIN=llvm${CLANG_VERSION}
export TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN}/prebuilt/${HOST_PLATFORM}/bin
export GCC_TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${GCC_TOOLCHAIN}/prebuilt/${HOST_PLATFORM}
export PATH=${PATH}:${TOOLCHAIN_PATH}
export CC=${TOOLCHAIN_PATH}/clang
export CXX=${TOOLCHAIN_PATH}/clang++
export AR=${NDK_ROOT}/toolchains/${ANDROID_PREFIX}-${TOOLCHAIN_VERSION}/prebuilt/${HOST_PLATFORM}/${ANDROID_PREFIX}/bin/ar
export RANLIB=${NDK_ROOT}/toolchains/${ANDROID_PREFIX}-${TOOLCHAIN_VERSION}/prebuilt/${HOST_PLATFORM}/${ANDROID_PREFIX}/bin/ranlib
export CFLAGS="-nostdlib --sysroot=${SYSROOT} -fno-short-enums"
export CFLAGS="$CFLAGS -I${SYSROOT}/usr/include/ -I${SYSROOT}/usr/include/${ANDROID_PREFIX} -I${NDK_ROOT}/sources/android/support/include -I${NDK_ROOT}/sources/cxx-stl/llvm-libc++/include -I${NDK_ROOT}/sources/android/cpufeatures "
export LDFLAGS=" -nostdlib -L${NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${ABI} -lz -llog  -lstdc++ -lgcc -lc -lm -ldl" #-lc++ -lc++abi -lunwind
export LIBS="-lz -llog  -lstdc++ -lgcc -lc -lm -ldl"
# -ldl -lm -lc "
#export ANDROID_SYSROOT=${SYSROOT}

if [ "$ABI" = "armeabi-v7a" ]; then
    export CFLAGS="$CFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    export LDFLAGS="$LDFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon -Wl,--fix-cortex-a8 -Wl,--no-undefined"
elif [ "$ABI" = "armeabi" ]; then
    export CFLAGS="$CFLAGS"
    export LDFLAGS="$LDFLAGS -Wl,--fix-cortex-a8 -shared -Wl,--no-undefined"
elif [ $ABI = "arm64-v8a" ]; then
    export CFLAGS="$CFLAGS -target aarch64-linux-android"
    export LDFLAGS="$LDFLAGS -target aarch64-linux-android"
elif [ "$ABI" = "x86_64" ]; then
    export CFLAGS="$CFLAGS -target x86_64 -march=x86_64 -msse3 -mstackrealign -mfpmath=sse -fno-stack-protector"
    export LDFLAGS="$LDFLAGS -target x86_64 -march=x86_64"
elif [ "$ABI" = "x86" ]; then
    export CFLAGS="$CFLAGS -target i686-none-linux-android -march=i686 -msse3 -mstackrealign -mfpmath=sse -fno-stack-protector"
    export LDFLAGS="$LDFLAGS -target i686-none-linux-android -march=i686"
fi
