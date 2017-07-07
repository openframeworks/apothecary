#! /bin/bash
set -e
trap 'previous_command=$this_command; this_command=$BASH_COMMAND' DEBUG
trap 'echo FAILED COMMAND: $previous_command' EXIT

#-------------------------------------------------------------------------------------------
# This script will download packages for, configure, build and install a GCC cross-compiler.
# Customize the variables (INSTALL_PATH, TARGET, etc.) to your liking before running.
# If you get an error and need to resume the script from some point in the middle,
# just delete/comment the preceding lines before running it again.
#
# See: http://preshing.com/20141119/how-to-build-a-gcc-cross-compiler
#-------------------------------------------------------------------------------------------

export BUILDROOT=$(cd $(dirname $0); pwd -P)
export SYSROOT=$(dirname $0)/../archlinux

if [ ! -d $SYSROOT ]; then
	wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz
	mkdir $SYSROOT
	tar xzf ArchLinuxARM-rpi-2-latest.tar.gz -C $SYSROOT 2> /dev/null
	rm ArchLinuxARM-rpi-2-latest.tar.gz
fi

export SYSROOT=$(cd $(dirname $0)/../archlinux; pwd -P)
mkdir -p $BUILDROOT/logs


INSTALL_PATH=$(cd $(dirname $0)/..; pwd -P)/rpi2_toolchain
TARGET=arm-linux-gnueabihf
LINUX_ARCH=arm
CONFIGURATION_OPTIONS="--disable-werror --with-arch=armv7-a --with-float=hard --with-fpu=vfpv3-d16"
SYSROOT_OPTIONS="--with-sysroot=$SYSROOT --with-build-sysroot=$SYSROOT"

PARALLEL_MAKE=-j8
BINUTILS_VERSION=binutils-2.28
GCC_VERSION=gcc-6.4.0
LINUX_KERNEL_VERSION=linux-4.9.35
GLIBC_VERSION=glibc-2.25
MPFR_VERSION=mpfr-3.1.5
GMP_VERSION=gmp-6.1.2
MPC_VERSION=mpc-1.0.3
ISL_VERSION=isl-0.12.2
CLOOG_VERSION=cloog-0.18.1
USE_NEWLIB=0
export PATH=$INSTALL_PATH/bin:$PATH

cd $(dirname $0)

# Download packages
export http_proxy=$HTTP_PROXY https_proxy=$HTTP_PROXY ftp_proxy=$HTTP_PROXY
if [ ! -f $BINUTILS_VERSION.tar.gz ]; then
	wget -nc https://ftp.gnu.org/gnu/binutils/$BINUTILS_VERSION.tar.gz
fi
if [ ! -f $GCC_VERSION.tar.gz ]; then
	wget -nc https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_VERSION.tar.gz
fi
if [ ! -f $LINUX_KERNEL_VERSION.tar.xz ]; then
	wget -nc https://www.kernel.org/pub/linux/kernel/v4.x/$LINUX_KERNEL_VERSION.tar.xz
fi
if [ ! -f $GLIBC_VERSION.tar.xz ]; then
	wget -nc https://ftp.gnu.org/gnu/glibc/$GLIBC_VERSION.tar.xz
fi
if [ ! -f $MPFR_VERSION.tar.xz ]; then
	wget -nc https://ftp.gnu.org/gnu/mpfr/$MPFR_VERSION.tar.xz
fi
if [ ! -f $GMP_VERSION.tar.xz ]; then
	wget -nc https://ftp.gnu.org/gnu/gmp/$GMP_VERSION.tar.xz
fi
if [ ! -f $MPC_VERSION.tar.gz ]; then
	wget -nc https://ftp.gnu.org/gnu/mpc/$MPC_VERSION.tar.gz
fi
if [ ! -f $ISL_VERSION.tar.bz2 ]; then
	wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$ISL_VERSION.tar.bz2
fi
if [ ! -f $CLOOG_VERSION.tar.gz ]; then
	wget -nc ftp://gcc.gnu.org/pub/gcc/infrastructure/$CLOOG_VERSION.tar.gz
fi


# Extract everything
echo "Uncompressing toolchain source"
for f in *.tar*; do tar xf $f; done

# Make symbolic links
cd $GCC_VERSION
ln -sf `ls -1d ../mpfr-*/` mpfr
ln -sf `ls -1d ../gmp-*/` gmp
ln -sf `ls -1d ../mpc-*/` mpc
ln -sf `ls -1d ../isl-*/` isl
ln -sf `ls -1d ../cloog-*/` cloog
cd ..


# Step 1. Binutils
mkdir -p build-binutils
cd build-binutils
echo Compiling binutils
../$BINUTILS_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS $SYSROOT_OPTIONS &> $BUILDROOT/logs/binutils.log
make $PARALLEL_MAKE &> $BUILDROOT/logs/binutils.log
make install &> $BUILDROOT/logs/binutils.log
cd ..

# Step 2. Linux Kernel Headers
if [ $USE_NEWLIB -eq 0 ]; then
    cd $LINUX_KERNEL_VERSION
	echo Compiling headers_install
    make ARCH=$LINUX_ARCH INSTALL_HDR_PATH=$INSTALL_PATH/$TARGET headers_install &> $BUILDROOT/logs/headers_install.log
    cd ..
fi

# Step 3. C/C++ Compilers
mkdir -p build-gcc
cd build-gcc
echo Compiling gcc
if [ $USE_NEWLIB -ne 0 ]; then
    NEWLIB_OPTION=--with-newlib
fi
../$GCC_VERSION/configure --prefix=$INSTALL_PATH --target=$TARGET --enable-languages=c,c++ --with-float=hard  --enable-multiarch --target=arm-linux-gnueabihf $CONFIGURATION_OPTIONS $SYSROOT_OPTIONS &> $SYSROOT/logs/gcc.log
make $PARALLEL_MAKE all-gcc &> $BUILDROOT/logs/gcc.log
make install-gcc &> $BUILDROOT/logs/gcc.log
cd ..

if [ $USE_NEWLIB -ne 0 ]; then
    # Steps 4-6: Newlib
    mkdir -p build-newlib
    cd build-newlib
	echo Compiling newlib
    ../newlib-master/configure --prefix=$INSTALL_PATH --target=$TARGET $CONFIGURATION_OPTIONS &> $BUILDROOT/logs/newlib.log
    make $PARALLEL_MAKE &> $BUILDROOT/logs/newlib.log
    make install &> $BUILDROOT/logs/newlib.log
    cd ..
else
    # Step 4. Standard C Library Headers and Startup Files
    mkdir -p build-glibc
    cd build-glibc
	echo Compiling glibc
    ../$GLIBC_VERSION/configure --prefix=$INSTALL_PATH/$TARGET --build=$MACHTYPE --host=$TARGET --target=$TARGET --with-headers=$INSTALL_PATH/$TARGET/include $CONFIGURATION_OPTIONS libc_cv_forced_unwind=yes &> $BUILDROOT/logs/glibc.log
    make install-bootstrap-headers=yes install-headers &> $BUILDROOT/logs/glibc.log
    make $PARALLEL_MAKE csu/subdir_lib &> $BUILDROOT/logs/glibc.log
    install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_PATH/$TARGET/lib &> $BUILDROOT/logs/glibc.log
    $TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $INSTALL_PATH/$TARGET/lib/libc.so &> $BUILDROOT/logs/glibc.log
    touch $INSTALL_PATH/$TARGET/include/gnu/stubs.h
    cd ..

    # Step 5. Compiler Support Library
    cd build-gcc
	echo compiling Compiler Support Library
    make $PARALLEL_MAKE all-target-libgcc &> $BUILDROOT/logs/gcclib.log
    make install-target-libgcc &> $BUILDROOT/logs/gcclib.log
    cd ..

    # Step 6. Standard C Library & the rest of Glibc
    cd build-glibc
	echo comiling rest of glibc
    make $PARALLEL_MAKE &> $BUILDROOT/logs/glibc.log
    make install &> $BUILDROOT/logs/glibc.log
    cd ..
fi

# Step 7. Standard C++ Library & the rest of GCC
cd build-gcc
echo compiling rest of gcc
make $PARALLEL_MAKE all &> $BUILDROOT/logs/gcc.log
make install &> $BUILDROOT/logs/gcc.log
cd ..

sed -i "s|${INSTALL_PATH}/arm-linux-gnueabihf/lib/||g" ${INSTALL_PATH}/arm-linux-gnueabihf/lib/libpthread.so
sed -i "s|${INSTALL_PATH}/arm-linux-gnueabihf/lib/||g" ${INSTALL_PATH}/arm-linux-gnueabihf/lib/libc.so

trap - EXIT
echo 'Success!'
