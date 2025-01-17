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
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd $APOTHECARY_LEVEL

CROSS_COMPILER=jetson
CROSS_URL="https://developer.nvidia.com/downloads/embedded/l4t/r36_release_v3.0/toolchain/aarch64--glibc--stable-2022.08-1.tar.bz2"
CROSS_NAME=aarch64--glibc--stable-2022.08-1.tar.bz2
CROSS_EXTRACT=aarch64--glibc--stable-2022.08-1

wget "${CROSS_URL}" -O ${CROSS_NAME}.tar.gz && tar xf ${CROSS_NAME}.tar.gz && rm ${CROSS_NAME}.tar.gz && mv ${CROSS_EXTRACT} ${CROSS_COMPILER}

echo "setup complete"
