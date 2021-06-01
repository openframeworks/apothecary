#!/usr/bin/env bash
export ABI=$1
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
if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
    export SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-arm"
    export LIB_SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-arm"
    export ANDROID_PREFIX=arm-${ANDROID_TOOLHOST}eabi
    export ANDROID_POSTFIX=${ANDROID_PREFIX}
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}
    export PLATFORM_LIBS=$SYSROOT/usr/lib
elif [ "$ABI" = "arm64-v8a" ]; then
    export SYSROOT="${NDK_ROOT}/sysroot"
    export LIB_SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-arm64"
    export ANDROID_PREFIX=aarch64-${ANDROID_TOOLHOST}
    export ANDROID_POSTFIX=${ANDROID_PREFIX}
    export GCC_TOOLCHAIN=$ANDROID_PREFIX-${TOOLCHAIN_VERSION}
    export PLATFORM_LIBS=$LIB_SYSROOT/usr/lib
elif [ "$ABI" = "x86" ]; then
    export SYSROOT="${NDK_ROOT}/sysroot"
    export LIB_SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-x86"
    export ANDROID_PREFIX=x86
    export ANDROID_POSTFIX=i686-${ANDROID_TOOLHOST}
    export GCC_TOOLCHAIN=x86-${TOOLCHAIN_VERSION}
    export PLATFORM_LIBS=$LIB_SYSROOT/usr/lib
elif [ "$ABI" = "x86_64" ]; then
    export SYSROOT="${NDK_ROOT}/sysroot"
    export LIB_SYSROOT="${NDK_ROOT}/platforms/$ANDROID_PLATFORM/arch-x86_64"
    export ANDROID_PREFIX=x86_64
    export ANDROID_POSTFIX=x86_64-${ANDROID_TOOLHOST}
    export GCC_TOOLCHAIN=x86_64-${TOOLCHAIN_VERSION}
    export PLATFORM_LIBS=$LIB_SYSROOT/usr/lib64
fi
export ANDROID_CMAKE_TOOLCHAIN=${NDK_ROOT}/build/cmake/android.toolchain.cmake
export TOOLCHAIN=llvm${CLANG_VERSION}
export TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN}/prebuilt/${HOST_PLATFORM}/bin
export DEEP_TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${TOOLCHAIN}/prebuilt/${HOST_PLATFORM}/sysroot/usr/lib/$ANDROID_POSTFIX/$ANDROID_API
export GCC_TOOLCHAIN_PATH=${NDK_ROOT}/toolchains/${GCC_TOOLCHAIN}/prebuilt/${HOST_PLATFORM}
export PATH=${PATH}:${TOOLCHAIN_PATH}
export CC=${TOOLCHAIN_PATH}/clang
export CXX=${TOOLCHAIN_PATH}/clang++
export AR=${NDK_ROOT}/toolchains/${ANDROID_PREFIX}-${TOOLCHAIN_VERSION}/prebuilt/${HOST_PLATFORM}/${ANDROID_POSTFIX}/bin/ar
export RANLIB=${NDK_ROOT}/toolchains/${ANDROID_PREFIX}-${TOOLCHAIN_VERSION}/prebuilt/${HOST_PLATFORM}/${ANDROID_POSTFIX}/bin/ranlib
export CFLAGS="-std=c17 --sysroot=${LIB_SYSROOT} -fno-short-enums -fPIE -fPIC -fuse-ld=gold"
export CPPFLAGS="-DANDROID_STL=c++_static -stdlib=libc++ -I${SYSROOT}/usr/include/ -I${SYSROOT}/usr/include/${ANDROID_POSTFIX} -I${NDK_ROOT}/sources/android/support/include -I${NDK_ROOT}/sources/cxx-stl/llvm-libc++/include -I${NDK_ROOT}/sources/android/cpufeatures"
export CXXFLAGS="-std=c++17 -stdlib=libc++ --sysroot=${LIB_SYSROOT} -fno-short-enums -fPIE -fPIC -fuse-ld=gold"

export LDFLAGS="-pie -L${LIB_SYSROOT}/usr/lib -L${NDK_ROOT}/sources/cxx-stl/llvm-libc++/libs/${ABI} -DANDROID_STL=c++_static -L$PLATFORM_LIBS -L$DEEP_TOOLCHAIN_PATH" #-lc++ -lc++abi -lunwind
export LIBS="-lz -lgcc -lc -lm -ldl"
# -ldl -lm -lc "
#export ANDROID_SYSROOT=${SYSROOT}

if [ "$ABI" = "armeabi-v7a" ]; then
    export CFLAGS="$CFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    export CPPFLAGS="$CPPFLAGS -I${NDK_ROOT}/sysroot/usr/include/arm-linux-androideabi -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    export LDFLAGS="$LDFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon -Wl,--fix-cortex-a8 -Wl,--no-undefined"
elif [ "$ABI" = "armeabi" ]; then
    export CFLAGS="$CFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    export CPPFLAGS="$CPPFLAGS -I${NDK_ROOT}/sysroot/usr/include/arm-linux-androideabi -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon"
    export LDFLAGS="$LDFLAGS -target armv7-none-linux-androideabi -march=armv7-a -mfloat-abi=softfp -mfpu=neon -Wl,--fix-cortex-a8 -Wl,--no-undefined"
elif [ $ABI = "arm64-v8a" ]; then
    export CFLAGS="$CFLAGS -target aarch64-linux-android -mfpu=neon"
    export CPPFLAGS="$CPPFLAGS -isystem -I${NDK_ROOT}/sysroot/usr/include/aarch64-linux-android -target aarch64-linux-android -mfpu=neon"
    export LDFLAGS="$LDFLAGS -target aarch64-linux-android -mfpu=neon"
elif [ "$ABI" = "x86_64" ]; then
    export CFLAGS="$CFLAGS -target x86_64-linux-android "
    export CPPFLAGS="$CFLAGS $CPPFLAGS -isystem -I${NDK_ROOT}/sysroot/usr/include/x86_64-linux-android -target x86_64-linux-android "
    export LDFLAGS="$LDFLAGS -target x86_64-linux-android -Wl,--fix-cortex-a8 -shared -Wl,--no-undefined"
elif [ "$ABI" = "x86" ]; then
    export CFLAGS="$CFLAGS -target i686-none-linux-android -march=i686 -msse3 -mstackrealign -mfpmath=sse -fno-stack-protector" 
    export CPPFLAGS="$CFLAGS $CPPFLAGS -I${NDK_ROOT}/sysroot/usr/include/i686-linux-android -target i686-none-linux-android -march=i686 -msse3 -mstackrealign -mfpmath=sse -fno-stack-protector"
    export LDFLAGS="$LDFLAGS -target i686-none-linux-android -march=i686"
fi

export CXXFLAGS="$CXXFLAGS $CPPFLAGS"
