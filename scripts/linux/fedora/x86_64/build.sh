#!/bin/bash
set -e
set -o pipefail
# trap any script errors and exit
trap "trapError" ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../../.." && pwd)"
cd $APOTHECARY_LEVEL

trapError() {
    echo
    echo " ^ Received error ^"
    cat formula.log
    exit 1
}

export ARCH=64
export TYPE=linux

echo "calculate formulas"
$APOTHECARY_LEVEL/scripts/calculate_formulas.sh

echo "building"
$APOTHECARY_LEVEL/scripts/build.sh
