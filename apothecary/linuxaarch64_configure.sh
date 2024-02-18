
export GCC_PREFIX=aarch64-linux-gnu
export GCC_VERSION=10.3.1
export GST_VERSION=1.0
export RPI_ROOT=$SYSROOT
export PLATFORM_OS=Linux
export PLATFORM_ARCH=aarch64
export PKG_CONFIG_LIBDIR=${RPI_ROOT}/usr/lib/pkgconfig:${RPI_ROOT}/usr/lib/${GCC_PREFIX}/pkgconfig:${RPI_ROOT}/usr/share/pkgconfig
export CXX="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-g++"
export CC="${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-gcc"
export AR=${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ar
export LD=${TOOLCHAIN_ROOT}/bin/${GCC_PREFIX}-ld

export PATH=/rpi_toolchain/bin/:$PATH
export LD_LIBRARY_PATH=/rpi_toolchain/lib

export CFLAGS="--sysroot=${SYSROOT} -I${TOOLCHAIN_ROOT}/${GCC_PREFIX}/libc/usr/include -I${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION}/include -I$SYSROOT/opt/vc/include -I$SYSROOT/opt/vc/include/IL -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST"

export LDFLAGS="--sysroot=${SYSROOT} -L${SYSROOT}/usr/lib/${GCC_PREFIX} -L${SYSROOT}/usr/lib/aarch64-linux-gnu -L${TOOLCHAIN_ROOT}/aarch64-linux-gnu/lib64 -L${TOOLCHAIN_ROOT}/aarch64-linux-gnu/libc/lib64 -L${TOOLCHAIN_ROOT}/lib/gcc/${GCC_PREFIX}/${GCC_VERSION} -L${SYSROOT}/lib/${GCC_PREFIX}"


export PKG_CONFIG_PATH=$SYSROOT/usr/lib/$GCC_PREFIX/pkgconfig:$SYSROOT/usr/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig
export CROSS_COMPILE=$TOOLCHAIN_ROOT/bin/$GCC_PREFIX-
export CXX=${CROSS_COMPILE}g++
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
# export CFLAGS="--sysroot=${SYSROOT} -I$SYSROOT/usr/include -march=armv8-a -fPIC -ftree-vectorize -Wno-psabi -pipe -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -DTARGET_POSIX -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -DUSE_EXTERNAL_OMX -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM"
# export LDFLAGS="--sysroot=${SYSROOT} -L$SYSROOT/usr/lib -L$SYSROOT/usr/lib/aarch64-linux-gnu"

export HOST=aarch64-linux-gnu
