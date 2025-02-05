#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd $APOTHECARY_LEVEL

CROSS_COMPILER="raspbian"
CROSS_SYSROOT="rpi_rootfs"
CROSS_ARCH="arm"
CROSS_MARCH=${CROSS_CPU:-"armv7l"}
CROSS_CPU=${CROSS_CPU:-"cortex-a7"}
CROSSCOMPILE=${CROSSCOMPILE:-1}

export HOST_ARCH=$(uname -m)
export HOST_PLATFORM=$(uname)

if [[ "$HOST_ARCH" != "$CROSS_MARCH" ]]; then
    CROSSCOMPILE=1
    echo "Detected different host ($HOST_ARCH) and target ($CROSS_MARCH). Enabling cross-compilation."
else
    CROSSCOMPILE=0
    echo "Native compilation detected. No cross-compilation needed."
fi

if [ "${CROSSCOMPILE}" -eq 0 ]; then
    export ROOTFS="/"
    export TOOLCHAIN_ROOT="/usr"
else
    export ROOTFS="${APOTHECARY_LEVEL}/${CROSS_SYSROOT}"
    export TOOLCHAIN_ROOT="${APOTHECARY_LEVEL}/${CROSS_COMPILER}"
fi

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

GCCPATH="$TOOLCHAIN_ROOT/libexec/gcc/${GCC_PREFIX}/${GCC_VERSION}"
export ARFLAGS="--plugin $GCCPATH/liblto_plugin.so"
export RANLIBFLAGS="--plugin $GCCPATH/liblto_plugin.so"

export CFLAGS="--sysroot=${SYSROOT} \
    -I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include \
    -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include \
    -march=armv7-a -mcpu=${CROSS_CPU} -mfpu=neon -mfloat-abi=hard \
    -fPIC -ftree-vectorize -Wno-psabi -pipe \
    -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE \
    -D_FILE_OFFSET_BITS=64 -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS \
    -DTARGET_POSIX -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -DUSE_EXTERNAL_OMX \
    -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM"

export LDFLAGS="--sysroot=${SYSROOT} \
    -Wl,-rpath-link,${TOOLCHAIN_ROOT}/${GCC_PREFIX}/lib \
    -L${TOOLCHAIN_ROOT}/lib \
    -Wl,-rpath-link,${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib"

export HOST="${GCC_PREFIX}"

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
echo "GCC Path: $GCCPATH"
echo "LDFLAGS : $LDFLAGS"
echo "CFLAGS : $CFLAGS"
echo "Path: [$PATH]"
echo "--------------------"
