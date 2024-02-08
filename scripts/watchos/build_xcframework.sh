#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
ROOT=$(cd $(dirname "$0"); pwd -P)/../../
APOTHECARY_PATH=$ROOT/apothecary

BUNDLE_NO="$1"
# Check if the argument is provided
if [ -z "${BUNDLE_NO+x}" ]; then
    echo "No argument provided."
    export BUNDLE=1
else
    echo "Argument 1: $BUNDLE_NO"
    export BUNDLE=$BUNDLE_NO
fi

export TARGET=watchos
export ARCH=arm64
export NO_FORCE=ON

echo "Target: $TARGET"
echo "Architecture: $ARCH"
echo "Bundle: $BUNDLE"
echo "Apothecary path: $APOTHECARY_PATH"

source ${ROOT}./scripts/calculate_formulas.sh
if [ -z "$FORMULAS" ]; then
    echo "No formulas to framework"
    exit 0
fi

for formula in "${FORMULAS[@]}" ; do
    formula_name="${formula%.*}"
    ARGS="$FORCE -t$TARGET -d$OUTPUT_FOLDER -a$ARCH"
    #echo "./apothecary $ARGS framework $formula_name"
    eval "cd $APOTHECARY_PATH";
    echo "---------"
    eval "./apothecary $ARGS framework $formula_name" 
    
done
echo "Apothecary openFrameworks Build XCFramework for $TARGET complete."
echo "========================"



