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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
ROOT=$(
    cd $(dirname "$0")
    pwd -P
)/../../../../../
APOTHECARY_PATH=$ROOT/apothecary
cd $APOTHECARY_LEVEL

CROSS_COMPILER=${CROSS_COMPILER:-raspbian}
CROSS_SYSROOT=${CROSS_SYSROOT:-rpi_rootfs}
CROSS_OS="${CROSS_OS:-bookworm}"

if grep -q "Raspbian" /etc/os-release 2>/dev/null && [[ "$(uname -m)" == "armv8l" ]]; then
    NATIVE="true"
    echo "Detected Raspberry Pi OS (Raspbian) on armv8l. Setting NATIVE=true"
else
    NATIVE="false"
fi

if [ "$CROSS_OS" == "bookworm" ]; then
    CROSS_URL="https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/Raspberry%20Pi%20GCC%20Cross-Compiler%20Toolchains/Buster/GCC%2014.2.0/Raspberry%20Pi%203A%2B%2C%203B%2B%2C%204%2C%205/cross-gcc-14.2.0-pi_3%2B.tar.gz/download"
    CROSS_NAME=cross-gcc-14.2.0-pi_3+
    CROSS_EXTRACT=cross-pi-gcc-14.2.0-2
elif [ "$CROSS_OS" == "Bullseye" ]; then
    # CROSS_URL="https://sourceforge.net/projects/raspberry-pi-cross-compilers/files/Bonus%20Raspberry%20Pi%20GCC%2064-Bit%20Toolchains/Raspberry%20Pi%20GCC%2064-Bit%20Cross-Compiler%20Toolchains/Bullseye/GCC%2013.1.0/cross-gcc-13.1.0-pi_64.tar.gz/download"
    # CROSS_NAME="cross-gcc-13.1.0-pi_64"
    # CROSS_EXTRACT="cross-pi-gcc-13.1.0-64"
    # echo "Using Bullseye toolchain: $CROSS_NAME"
    echo "Unsupported CROSS_OS value: $CROSS_OS"
    exit 1
else
    echo "Unsupported CROSS_OS value: $CROSS_OS"
    exit 1
fi

wget "${CROSS_URL}" -O ${CROSS_NAME}.tar.gz && tar xf ${CROSS_NAME}.tar.gz && rm ${CROSS_NAME}.tar.gz && mv ${CROSS_EXTRACT} ${CROSS_COMPILER}

if [ "$NATIVE" == "0" ]; then
    git clone https://github.com/danoli3/rpi_rootfs.git
    cd $CROSS_SYSROOT

    sudo chmod +x ./build_rootfs.sh
    ./build_rootfs.sh download
    ./build_rootfs.sh create

fi

echo "===setup complete==="
cd $SCRIPT_DIR

