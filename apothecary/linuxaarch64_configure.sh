export PKG_CONFIG_PATH=$SYSROOT/usr/lib/$TOOLCHAIN_PREFIX/pkgconfig:$SYSROOT/usr/share/pkgconfig:$SYSROOT/usr/lib/pkgconfig
export CROSS_COMPILE=$TOOLCHAIN_ROOT/bin/$TOOLCHAIN_PREFIX-
export CXX=${CROSS_COMPILE}g++
export CC=${CROSS_COMPILE}gcc
export AR=${CROSS_COMPILE}ar
export LD=${CROSS_COMPILE}ld
export RANLIB=${CROSS_COMPILE}ranlib
export CFLAGS="--sysroot=${SYSROOT} -I$SYSROOT/usr/include -I$SYSROOT/opt/vc/include -I$SYSROOT/opt/vc/include/IL -I$SYSROOT/opt/vc/include/interface/vcos/pthreads -I$SYSROOT/opt/vc/include/interface/vmcs_host/linux -I$SYSROOT/opt/vc/lib -march=armv8-a -mfpu=vfp -mfloat-abi=hard -fPIC -ftree-vectorize -Wno-psabi -pipe -DSTANDALONE -DPIC -D_REENTRANT -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -DTARGET_POSIX -DHAVE_LIBOPENMAX=2 -DOMX -DOMX_SKIP64BIT -DUSE_EXTERNAL_OMX -DHAVE_LIBBCM_HOST -DUSE_EXTERNAL_LIBBCM_HOST -DUSE_VCHIQ_ARM"
export LDFLAGS="--sysroot=${SYSROOT} -L$SYSROOT/usr/lib -L$SYSROOT/usr/lib/aarch64-linux-gnu -lm -march=armv8-a"
export HOST=aarch64-linux-gnu

GCCPATH="$TOOLCHAIN_ROOT/libexec/gcc/aarch64-linux-gnu/10.3.1"
export ARFLAGS="--plugin $GCCPATH/liblto_plugin.so"
export RANLIBFLAGS="--plugin $GCCPATH/liblto_plugin.so"

export PATH=$TOOLCHAIN_ROOT/bin/bin:$PATH
export LD_LIBRARY_PATH=$TOOLCHAIN_ROOT/lib
