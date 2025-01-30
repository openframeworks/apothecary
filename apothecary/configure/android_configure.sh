#!/usr/bin/env bash

# Set script directory
ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"

export MAKE_TARGET="${MAKE_TARGET:-cmake}"
export NDK_VERSION_MAJOR="${NDK_VERSION_MAJOR:-27}"
export ANDROID_API="${ANDROID_API:-34}" #minimum Android API supported. 21 default

if [ -z "$1" ]; then
    echo "Error: ABI is not specified. Usage: $0 <ABI> [BUILD_SYSTEM]" >&2
    exit 1
fi
export ABI=$1
export ANDROID_ABI=$1
export BUILD_SYSTEM=${2:-make}

export TOOLCHAIN_ROOT="${APOTHECARY_LEVEL}/android"
export NDK_ROOT="${ANDROID_NDK_ROOT}"

export HOST_ARCH=$(uname -m)
case "$(uname)" in
    Darwin) HOST_PLATFORM="darwin-x86_64" ;;
    Linux)  HOST_PLATFORM="linux-x86_64" ;;
    Windows) HOST_PLATFORM="windows-x86_64" ;;
    *) echo "Error: Unsupported host platform." >&2; exit 1 ;;
esac

case "$ABI" in
    armeabi-v7a)
        MACHINE=armv7
        ANDROID_PREFIX=arm-linux-androideabi
        MAKE_TARGET="-target armv7-linux-androideabi -march=armv7-a"
        ;;
    arm64-v8a)
        MACHINE=arm64
        ANDROID_PREFIX=aarch64-linux-android
        MAKE_TARGET="-target aarch64-linux-android"
        ;;
    x86)
        MACHINE=i686
        ANDROID_PREFIX=i686-linux-android
        MAKE_TARGET="-target i686-linux-android -march=i686"
        ;;
    x86_64)
        MACHINE=x86_64
        ANDROID_PREFIX=x86_64-linux-android
        MAKE_TARGET="-target x86_64-linux-android"
        ;;
    *)
        echo "Error: Unsupported ABI '$ABI'." >&2
        exit 1
        ;;
esac

# Toolchain
export SYSROOT="${NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_PLATFORM}/sysroot"
export TOOLCHAIN_PATH="${NDK_ROOT}/toolchains/llvm/prebuilt/${HOST_PLATFORM}/bin"
# export PATH="$TOOLCHAIN_PATH:$PATH"

# Compiler
# export AR="$TOOLCHAIN_PATH/llvm-ar"
# export CC="$TOOLCHAIN_PATH/${ANDROID_PREFIX}${ANDROID_API}-clang"
# export CXX="$TOOLCHAIN_PATH/${ANDROID_PREFIX}${ANDROID_API}-clang++"
# export LDFLAGS="-pie -L${SYSROOT}/usr/lib/$ANDROID_PREFIX/$ANDROID_API
# echo "debug paths"
# echo "${NDK_ROOT}/toolchains/llvm/prebuilt/"
# ls -a ${NDK_ROOT}/toolchains/llvm/prebuilt/
# echo "${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/"
# ls -a ${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/
# echo "${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin"
# ls -a ${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/

# Debug output
echo -e "\n\033[1;32m==== Android Toolchain Configuration ====\033[0m"
echo "NDK Root         : $NDK_ROOT"
echo "ANDROID_NDK_ROOT : $ANDROID_NDK_ROOT"
echo "Toolchain Type   : llvm"
echo "Host Platform    : $HOST_PLATFORM"
echo "ANDROID_ABI      : $ABI"
echo "ANDROID_API      : $ANDROID_API"
echo "Sysroot          : $SYSROOT"
echo "Toolchain Path   : $TOOLCHAIN_PATH"
# echo "CFLAGS           : $CFLAGS"
# echo "LDFLAGS          : $LDFLAGS"
echo -e "=========================================\n"

cd "$ORIGINAL_DIR"
