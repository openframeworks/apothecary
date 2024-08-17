#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

if [ -z "${NO_FORCE+x}" ]; then
    export FORCE="-f"
else
    export FORCE=""
fi

# trap any script errors and exit
# trap "trapError" ERR

trapError() {
    echo
    echo " ^ Received error building $formula_name ^"
    cat "formula_${ARCH}.log"
    if [ "$formula_name" == "boost" ]; then
        cat $APOTHECARY_PATH/build/boost/bootstrap.log
    fi
    if [ -f $APOTHECARY_PATH/build/$formula_name/config.log ]; then
        tail -n1000 $APOTHECARY_PATH/build/$formula_name/config.log
    fi
    exit 1
}

if [ "$TRAVIS" = true  -o "$GITHUB_ACTIONS" = true ] && [ "$TARGET" == "emscripten" ]; then
    run(){
        echo "TARGET=\"emscripten\" $@"
        docker exec -i emscripten sh -c "TARGET=\"emscripten\" $@"
    }

    run_bg(){
        trap "trapError" ERR

        #PATH=\"$DOCKER_HOME/bin:\$PATH\"
        echo "TARGET=\"emscripten\" $@"
        docker exec -i emscripten sh -c "TARGET=\"emscripten\" $@"  >> "formula_${ARCH}.log" 2>&1 &
        apothecaryPID=$!
        echoDots $apothecaryPID
        wait $apothecaryPID

        echo "Tail of log for $formula_name"
        run "tail -n 100 formula_${ARCH}.log"
    }

    # DOCKER_HOME=$(docker exec -i emscripten echo '$HOME')
    # CCACHE_DOCKER=$(docker exec -i emscripten ccache -p | grep "cache_dir =" | sed "s/(default) cache_dir = \(.*\)/\1/")
    ROOT=$(docker exec -i emscripten pwd)
    LOCAL_ROOT=$(cd $(dirname "$0"); pwd -P)/../..
else
    run(){
        echo "$@"
        eval "$@"
    }

    run_bg(){
        trap "trapError" ERR

        echo "$@"
        eval "$@" >> "formula_${ARCH}.log" 2>&1 &
        apothecaryPID=$!
        echoDots $apothecaryPID
        wait $apothecaryPID

        echo "Tail of log for $formula_name"
        run "tail -n 10 formula_${ARCH}.log"
    }

    ROOT=$(cd $(dirname "$0"); pwd -P)/../..
    LOCAL_ROOT=$ROOT
fi

APOTHECARY_PATH=$ROOT/apothecary

if [ -z "${OUTPUT_FOLDER+x}" ]; then
    export OUTPUT_FOLDER="$ROOT/xout"
fi

if [ -z "$1" ]; then
   echo " TARGET: $1"
else
    TARGET=$1
fi

if [ -z "$2" ]; then
   echo " Bundle: $2"
else
    BUNDLE=$2
fi

#OUTPUT_FOLDER=$ROOT/out
# VERBOSE=true

if [ -z $TARGET ] ; then
    echo "Environment variable TARGET not defined. Should be target os"
    exit 1
fi

echo "Running apothecary from $PWD"
echo "Target: $TARGET"
echo "Architecture: $ARCH"
echo "Bundle: $BUNDLE"
echo "Apothecary path: $APOTHECARY_PATH"
echo "Output folder is: $OUTPUT_FOLDER"

# Source the calculate_formulas.sh script to get the list of formulas
source $LOCAL_ROOT/scripts/calculate_formulas.sh

if [ -z "$FORMULAS" ]; then
    echo "No formulas to build"
    exit 0
fi

# Define the base directory where the library folders are located
LIBRARY_BASE_DIR="$LOCAL_ROOT/libraries"

# Create an associative array to keep track of the libraries to keep
declare -A KEEP_LIBRARIES
for formula in "${FORMULAS[@]}"; do
    formula_name="${formula%.*}"
    KEEP_LIBRARIES[$formula_name]=1
done

OUT_BUNDLE_DIR="${OUTPUT_FOLDER}_$BUNDLE"
mkdir -p "$OUT_BUNDLE_DIR"

# Iterate over the folders in the library base directory
for LIBRARY_DIR in "$OUTPUT_FOLDER"/*; do
    LIBRARY_NAME=$(basename "$LIBRARY_DIR")
    
    # Check if the library name is in the keep list
    if [ -n "${KEEP_LIBRARIES[$LIBRARY_NAME]}" ]; then
        echo "Moving library folder: $LIBRARY_DIR to $OUT_BUNDLE_DIR"
        mv "$LIBRARY_DIR" "$OUT_BUNDLE_DIR/"
    else
        echo "Keeping library folder: $LIBRARY_DIR in $OUTPUT_FOLDER"
    fi
done

echo ""
echo ""
