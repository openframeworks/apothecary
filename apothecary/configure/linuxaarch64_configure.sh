#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd $APOTHECARY_LEVEL

CROSS_COMPILER="raspbian"
CROSS_SYSROOT="rpi_rootfs"
CROSS_ARCH="aarch64"
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
export GCC_PREFIX="${CROSS_ARCH}-linux-gnu"
if [ "${GCC_VERSION}" -eq 0 ]; then
    export GCC_VERSION="14.2.0"
fi

export CMAKE_LIBRARY_ARCHITECTURE=${GCC_PREFIX}
export LIBRARY_PATH=${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib64:${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib:${TOOLCHAIN_ROOT}/lib
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
export ARFLAGS="--plugin ${GCCPATH}/liblto_plugin.so"
export RANLIBFLAGS="--plugin ${GCCPATH}/liblto_plugin.so"

export CFLAGS="--sysroot=${SYSROOT} \
    -I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include \
    -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include \
    -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE \
    -D_FILE_OFFSET_BITS=64 \
    -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST"

export LDFLAGS="--sysroot=${SYSROOT} \
    -Wl,-rpath-link,${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${SYSROOT}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
    -Wl,-rpath-link,${SYSROOT}/usr/lib64/${CMAKE_LIBRARY_ARCHITECTURE} \
    -L${SYSROOT}/usr/lib64/${CMAKE_LIBRARY_ARCHITECTURE} \
    -Wl,-rpath-link,${TOOLCHAIN_ROOT}/${GCC_PREFIX}/lib64 \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib64 \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib \
    -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib64 \
    -L${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}"

[ -d "${ROOTFS}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}" ] && ls -la "${ROOTFS}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}" || echo "Directory not found: ${ROOTFS}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}"
[ -d "${TOOLCHAIN_ROOT}/${CMAKE_LIBRARY_ARCHITECTURE}/lib64" ] && ls -la "${TOOLCHAIN_ROOT}/${CMAKE_LIBRARY_ARCHITECTURE}/lib64" || echo "Directory not found: ${TOOLCHAIN_ROOT}/${CMAKE_LIBRARY_ARCHITECTURE}/lib64"
[ -d "${TOOLCHAIN_ROOT}/lib/gcc/${CMAKE_LIBRARY_ARCHITECTURE}/${GCC_VERSION}" ] && ls -la "${TOOLCHAIN_ROOT}/lib/gcc/${CMAKE_LIBRARY_ARCHITECTURE}/${GCC_VERSION}" || echo "Directory not found: ${TOOLCHAIN_ROOT}/lib/gcc/${CMAKE_LIBRARY_ARCHITECTURE}/${GCC_VERSION}"

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
echo "GCC Path: $GCCPATH"
echo "LDFLAGS : $LDFLAGS"
echo "CFLAGS : $CFLAGS"
echo "Path: [$PATH]"
echo "--------------------"
