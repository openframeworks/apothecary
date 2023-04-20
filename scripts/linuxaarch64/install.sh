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

ROOT=/home/runner/work/apothecary/apothecary
echo $ROOT
cd $ROOT
RASP="$ROOT/raspbian"

 wget  https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/Bonus%20Raspberry%20Pi%20GCC%2064-Bit%20Toolchains/Raspberry%20Pi%20GCC%2064-Bit%20Cross-Compiler%20Toolchains/Bullseye/GCC%2010.3.0/cross-gcc-10.3.0-pi_64.tar.gz --no-check-certificate

tar xf cross-gcc-10.3.0-pi_64.tar.gz
rm cross-gcc-10.3.0-pi_64.tar.gz
mv cross-pi-gcc-10.3.0-64 raspbian

PATH=$RASP/bin:$PATH
LD_LIBRARY_PATH=$RASP/lib:$LD_LIBRARY_PATH

export AR="aarch64-linux-gnu-gcc-ar"
export CC="aarch64-linux-gnu-gcc"
export CXX="aarch64-linux-gnu-g++"
export CPP="aarch64-linux-gnu-cpp"
export FC="aarch64-linux-gnu-gfortran"
export RANLIB="aarch64-linux-gnu-gcc-ranlib"
export LD="$CXX"

GCCPATH="$RASP/libexec/gcc/aarch64-linux-gnu/10.3.1"
export ARFLAGS="--plugin $GCCPATH/liblto_plugin.so"
export RANLIBFLAGS="--plugin $GCCPATH/liblto_plugin.so"

echo "ROOT dir "
ls -la $ROOT

echo "RASP dir "
ls -la $RASP

echo "GCCPATH IS "
echo $GCCPATH

echo "calculate formulas"
$ROOT/scripts/calculate_formulas.sh

echo "building"
$ROOT/scripts/build.sh
