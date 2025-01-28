#!/usr/bin/env bash

ORIGINAL_DIR="$(pwd)"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$( cd "$SCRIPT_DIR/../.." && pwd )"
cd $APOTHECARY_LEVEL

CROSS_ARCH="aarch64"
CROSSCOMPILE=${CROSSCOMPILE:-0} # Default to native compilation
SYSROOT_PATH="/usr/${CROSS_ARCH}-linux-gnu"

# Initialize toolchain variables
export GCC_PREFIX="${CROSS_ARCH}-linux-gnu"
export CROSS_COMPILER=""
export ROOTFS=""
export TOOLCHAIN_ROOT=""

# Determine if cross-compilation is needed
if [ -d "${SYSROOT_PATH}" ]; then
    CROSSCOMPILE=1
    ROOTFS="${SYSROOT_PATH}"
    TOOLCHAIN_ROOT="${SYSROOT_PATH}"
    echo "Cross-compiling detected. Using sysroot at ${SYSROOT_PATH}"
else
    CROSSCOMPILE=0
    ROOTFS="/"
    TOOLCHAIN_ROOT="/usr"
    echo "Native compilation detected. Using rootfs at ${ROOTFS}"
fi
export HOST_ARCH=$(uname -m)
export HOST_PLATFORM=$(uname)
export SYSROOT=${ROOTFS}

# if [ "${GCC_VERSION}" -eq 0 ]; then
#     export GCC_VERSION="14.2.0"
# fi

# export CMAKE_LIBRARY_ARCHITECTURE=${GCC_PREFIX}
# export LIBRARY_PATH=${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib64:${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib:${TOOLCHAIN_ROOT}/lib
# export LD_LIBRARY_PATH=${TOOLCHAIN_ROOT}/lib
# export PATH=$TOOLCHAIN_ROOT/bin:$LIBRARY_PATH:$PATH

# export CC="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-gcc"
# export CXX="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-g++"
# export CPP="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-cpp"
# export AR="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ar"
# export AS="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-as"
# export RANLIB="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ranlib"
# export FC="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-gfortran"
# export LD="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ld"
#
# export CFLAGS=""
#  # \
#  #    -I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include \
#  #    -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include \
#  #    -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE \
#  #    -D_FILE_OFFSET_BITS=64 \
#  #    -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST"

# export LDFLAGS=""
#     # -Wl,-rpath-link,${ROOTFS}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
#     # -L${ROOTFS}/usr/lib/${CMAKE_LIBRARY_ARCHITECTURE} \
#     # -Wl,-rpath-link,${ROOTFS}/usr/lib64/${CMAKE_LIBRARY_ARCHITECTURE} \
#     # -L${ROOTFS}/usr/lib64/${CMAKE_LIBRARY_ARCHITECTURE} \
#     # -Wl,-rpath-link,${TOOLCHAIN_ROOT}/${GCC_PREFIX}/lib64 \
#     # -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/lib64 \
#     # -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib \
#     # -L${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/lib64 \
#     # -L${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}"

# tools=("gcc" "g++" "cpp" "ar" "as" "ranlib" "gfortran" "ld")

# # Check each tool
# for tool in "${tools[@]}"; do
#     filepath="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-${tool}"
#     if [[ -f "$filepath" ]]; then
#         echo "Found: $filepath"
#     else
#         echo "Missing: [$tool] - [$filepath]"
#     fi
# done

# Debugging output
echo "--------------------"
echo "openFrameworks apothecary Cross Compiler: $GCC_PREFIX"
# echo "Using GCC Version: $GCC_VERSION"
# echo "Library Path: $LIBRARY_PATH"
echo "ROOTFS Path: $ROOTFS"
# echo "Toolchain ROOT: $TOOLCHAIN_ROOT"
# echo "CROSS_ARCH: $CROSS_ARCH"
echo "HOST_ARCH: $HOST_ARCH"
echo "HOST_PLATFORM: $HOST_PLATFORM"
# echo "LDFLAGS : $LDFLAGS"
# echo "CFLAGS : $CFLAGS"
# echo "Path: [$PATH]"
# echo "--------------------"
cd "$ORIGINAL_DIR"
