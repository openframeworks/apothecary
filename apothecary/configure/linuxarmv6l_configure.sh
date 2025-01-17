#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd $APOTHECARY_LEVEL

CROSS_COMPILER="raspbian"
CROSS_SYSROOT="rpi_rootfs"
CROSS_ARCH="arm"
CROSS_CPU=${CROSS_CPU:-"arm1176jzf-s"}
CROSSCOMPILE=${CROSSCOMPILE:-1}

if [ "${CROSSCOMPILE}" -eq 0 ]; then
    export ROOTFS="/"
    export TOOLCHAIN_ROOT="/${CROSS_COMPILER}"
else
    export ROOTFS="${APOTHECARY_LEVEL}/${CROSS_SYSROOT}"
    export TOOLCHAIN_ROOT="${APOTHECARY_LEVEL}/${CROSS_COMPILER}"
fi
export HOST_ARCH=$(uname -m)
export HOST_PLATFORM=$(uname)
export SYSROOT=${ROOTFS}
export GCC_PREFIX="${CROSS_ARCH}-linux-gnueabihf"
export GCC_VERSION="1.0"

CMAKE_LIBRARY_ARCHITECTURE=${GCC_PREFIX}
export LIBRARY_PATH=${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib:${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib:${TOOLCHAIN_ROOT}/lib
export LD_LIBRARY_PATH=${TOOLCHAIN_ROOT}/lib
export PATH=$TOOLCHAIN_ROOT/bin:$LIBRARY_PATH:$PATH

export CC="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-gcc"
export CXX="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-g++"
export CPP="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-cpp"
export AR="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ar"
export AS="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-as"
export RANLIB="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ranlib"
export FC="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-gfortran"
export LD="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ld"

# GCCPATH="$TOOLCHAIN_ROOT/libexec/gcc/${GCC_PREFIX}/${GCC_VERSION}"
# export ARFLAGS="--plugin $GCCPATH/liblto_plugin.so"
# export RANLIBFLAGS="--plugin $GCCPATH/liblto_plugin.so"
export PKG_CONFIG_PATH="$SYSROOT/usr/lib/$GCC_PREFIX/pkgconfig:$SYSROOT/usr/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig"

export CFLAGS="--sysroot=${SYSROOT} \
	-I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include \
    -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include \
    -march=armv6 -mcpu=${CROSS_CPU}-mfpu=vfp -mfloat-abi=hard -fPIC -ftree-vectorize -Wno-psabi -pipe -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -DTARGET_POSIX -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -DUSE_EXTERNAL_OMX -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM"

export LDFLAGS="--sysroot=${SYSROOT} -Wl,-rpath-link,${TOOLCHAIN_ROOT}/${GCC_PREFIX}/lib \
    -L${TOOLCHAIN_ROOT}/lib \
    -Wl,-rpath-link,${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib -lm"

export HOST="${GCC_PREFIX}"

tools=("gcc" "g++" "cpp" "ar" "as" "ranlib" "gfortran" "ld")

# Check each tool
for tool in "${tools[@]}"; do
    filepath="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-${tool}"
    if [[ -f "$filepath" ]]; then
        echo "Found: $filepath"
    else
        echo "Missing: [$tool] - [$filepath]"
    fi
done

# Debugging output
echo "--------------------"
echo "openFrameworks apothecary Cross Compiler: $GCC_PREFIX"
echo "Using GCC Version: $GCC_VERSION"
echo "Library Path: $LIBRARY_PATH"
echo "ROOTFS Path: $ROOTFS"
echo "Toolchain ROOT: $TOOLCHAIN_ROOT"
echo "CROSS_ARCH: $CROSS_ARCH"
echo "HOST_ARCH: $HOST_ARCH"
echo "HOST_PLATFORM: $HOST_PLATFORM"
echo "LDFLAGS : $LDFLAGS"
echo "CFLAGS : $CFLAGS"
echo "Path: [$PATH]"
echo "--------------------"
