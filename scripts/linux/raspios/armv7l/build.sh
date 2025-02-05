#!/bin/bash
set -e
set -o pipefail
# trap any script errors and exit
trap "trapError" ERR

trapError() {
    echo
    echo " ^ Received error ^"
    cat formula.log
    exit 1
}

export ARCH=armv7l
export TYPE=linux

SCRIPT_DIR=$(
    cd $(dirname "$0")
    pwd -P
)
ROOT=$(
    cd $(dirname "$0")
    pwd -P
)/../../../../
APOTHECARY_PATH=$ROOT/apothecary

# export GCC_PREFIX=arm-linux-gnueabihf
# export GCC_VERSION="14.2.0" # UPDATE THIS AS NEEDED /libexec/gcc/arm-linux-gnueabihf/*/
# LD_LIBRARY_PATH=${RASP}/${GCC_PREFIX}/libc/usr/lib:${RASP}/${GCC_PREFIX}/libc/lib:${RASP}/lib

# export AR="${GCC_PREFIX}-gcc-ar"
# export CC="${GCC_PREFIX}-gcc"
# export CXX="${GCC_PREFIX}-g++"
# export CPP="${GCC_PREFIX}-cpp"
# export FC="${GCC_PREFIX}-gfortran"
# export RANLIB="${GCC_PREFIX}-ranlib"
# export LD="${GCC_PREFIX}-ld"

# GCCPATH="$RASP/libexec/gcc/${GCC_PREFIX}/${GCC_VERSION}"
# export ARFLAGS="--plugin $GCCPATH/liblto_plugin.so"
# export RANLIBFLAGS="--plugin $GCCPATH/liblto_plugin.so"

# export LIBC_USR=${RASP}/${GCC_PREFIX}/libc/usr/
# export CRT=${LIBC_USR}/lib

# sudo chmod +x SSymlinker
# ./SSymlinker -s ${LIBC_USR}/include/asm -d /usr/include
# ./SSymlinker -s ${LIBC_USR}/include/gnu -d /usr/include
# ./SSymlinker -s ${LIBC_USR}/include/bits -d /usr/include
# ./SSymlinker -s ${LIBC_USR}/include/sys -d /usr/include
# # ./SSymlinker -s ${LIBC_USR}/include/sound -d /usr/include
# ./SSymlinker -s ${LIBC_USR}/include/video -d /usr/include
# ./SSymlinker -s ${LIBC_USR}/include -d /usr/include
# ./SSymlinker -s ${CRT}/crtn.o -d /usr/lib/crtn.o
# ./SSymlinker -s ${CRT}/crt1.o -d /usr/lib/crt1.o
# ./SSymlinker -s ${CRT}/crti.o -d /usr/lib/crti.o

# echo 'export PATH=$PATH' >> .bashrc
# echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH' >> .bashrc
# source .bashrc

#echo "ROOT dir "
#ls -la $ROOT
#
#echo "RASP dir "
#ls -la $RASP
#
#echo "GCCPATH IS "
#echo $GCCPATH

echo "calculate formulas"
$APOTHECARY_LEVEL/scripts/calculate_formulas.sh

echo "building"
$APOTHECARY_LEVEL/scripts/build.sh

echo "===build complete==="
cd $SCRIPT_DIR
