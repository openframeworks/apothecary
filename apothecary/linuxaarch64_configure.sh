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

export HOST=aarch64-linux-gnu
