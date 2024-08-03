#!/usr/bin/env bash
# set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

if [ -z "${NO_FORCE+x}" ]; then
    export FORCE="-f"
else
    export FORCE=""
fi

if [ -z "${ARCH+x}" ]; then
    echo "Build: ARCH is set to: $ARCH"
fi

if [ -z "${PTHREADS_ENABLED+x}" ]; then
    export PTHREADS_ENABLED=1
fi

# Print the value to verify it's set
echo "PTHREADS_ENABLED is set to: $PTHREADS_ENABLED"

# Your existing build logic here

# Example of using the variable
if [ "$PTHREADS_ENABLED" -eq 1 ]; then
    echo "pThreads is enabled"
else
    echo "pThreads is not enabled"
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
    LOCAL_ROOT=$(cd $(dirname "$0"); pwd -P)/..
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

    ROOT=$(cd $(dirname "$0"); pwd -P)/..
    LOCAL_ROOT=$ROOT
fi

APOTHECARY_PATH=$ROOT/apothecary

if [ -z "${OUTPUT_FOLDER+x}" ]; then
    export OUTPUT_FOLDER="$ROOT/out"
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


isRunning(){
    if [ “$(uname)” == “Linux” ]; then
		if [ -d /proc/$1 ]; then
	    	return 0
        else
            return 1
        fi
    else
        number=$(ps aux | sed -E "s/[^ ]* +([^ ]*).*/\1/g" | grep ^$1$ | wc -l)

        if [ $number -gt 0 ]; then
            return 0;
        else
            return 1;
        fi
    fi
}

echoDots(){
    sleep 0.1 # Waiting for a brief period first, allowing jobs returning immediatly to finish
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return;
            fi
            sleep 1
        done
        printf "\r                    "
        printf "\r"
    done
}


travis_fold_start() {
  echo -e "travis_fold:start:$1\033[33;1m$2\033[0m"
}

travis_fold_end() {
  echo -e "\ntravis_fold:end:$1\r"
}

travis_time_start() {
  travis_timer_id=$(printf %08x $(( RANDOM * RANDOM )))
  travis_start_time=$(travis_nanoseconds)
  echo -en "travis_time:start:$travis_timer_id\r${ANSI_CLEAR}"
}

travis_time_finish() {
  local result=$?
  travis_end_time=$(travis_nanoseconds)
  local duration=$(($travis_end_time-$travis_start_time))
  echo -en "\ntravis_time:end:$travis_timer_id:start=$travis_start_time,finish=$travis_end_time,duration=$duration\r${ANSI_CLEAR}"
  return $result
}

function travis_nanoseconds() {
  local cmd="date"
  local format="+%s%N"
  local os=$(uname)

  if hash gdate > /dev/null 2>&1; then
    cmd="gdate" # use gdate if available
  elif [[ "$os" = Darwin ]]; then
    format="+%s000000000" # fallback to second precision on darwin (does not support %N)
  fi

  $cmd -u $format
}

if [ -z ${PARALLEL+x} ]; then
    if [ "$TARGET" == "osx" ] || [ "$TARGET" == "macos" ]; then
        PARALLEL=4
    elif [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ]; then
        PARALLEL=2
    elif [ "$TARGET" == "android" ]; then
        PARALLEL=2
    elif [ "$TARGET" == "vs" ] || [ "$TARGET" == "msys2" ]; then
        PARALLEL=4
    else
        PARALLEL=2
    fi
fi

echo "Parallel builds: $PARALLEL"

if  type "ccache" > /dev/null; then
    if [ "$TRAVIS_OS_NAME" == "osx" ]; then
       export PATH="/usr/local/opt/ccache/libexec:$PATH";
       export SDKROOT="$DEVELOPER_DIR/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    fi

    # if [ "$TRAVIS" = true ] && [ "$TARGET" == "emscripten" ]; then
    #     docker exec -it emscripten sh -c 'echo $HOME'
    #     docker cp /home/travis/.ccache emscripten:$CCACHE_DOCKER
    # fi

    ccache -z
    ccache -s
    # if [ "$TRAVIS" = true ] && [ "$TARGET" == "emscripten" ]; then
    #     run "ccache -z"
    #     run "ccache -s"
    # fi
fi

if [ "$TARGET" == "linux" ]; then
    export TARGET="linux64"
    if [ "$OPT" == "gcc5" ]; then
        export CC="gcc-5"
        export CXX="g++-5 -std=c++11"
        export COMPILER="g++5 -std=c++11"
    elif [ "$OPT" == "gcc6" ]; then
        export CC="gcc-6 -fPIE"
        export CXX="g++-6 -std=c++14 -fPIE"
        export COMPILER="g++6 -std=c++14 -fPIE"
    elif [ "$OPT" == "gcc14" ]; then
        export CC="gcc-14 -fPIE"
        export CXX="g++-14 -std=c++23 -fPIE"
        export COMPILER="g++14 -std=c++23 -fPIE"
    fi
fi

function build(){
    trap "trapError" ERR

    echo "Build $formula_name $FORCE"

    local ARGS="$FORCE -j$PARALLEL -t$TARGET -d$OUTPUT_FOLDER "
	if [ "$GITHUB_ACTIONS" = true ] && [ "$TARGET" == "vs" ]; then
		ARGS="-e $ARGS"
	fi

    if [ "$PTHREADS_ENABLED" -eq 1 ]; then
        ARGS="$ARGS -y "
    fi

    if [ "$ARCH" != "" ] ; then
        ARGS="$ARGS -a$ARCH"
    fi

    if [ "$VERBOSE" = true ] ; then
        echo "./apothecary $ARGS update $formula_name"
        run "cd $APOTHECARY_PATH;./apothecary $ARGS update $formula_name"
    else
        echo "./apothecary $ARGS update $formula_name" >> "formula_${ARCH}.log" 2>&1
        run_bg "cd $APOTHECARY_PATH;./apothecary $ARGS update $formula_name"
    fi

}

source $LOCAL_ROOT/scripts/calculate_formulas.sh

if [ -z "$FORMULAS" ]; then
    echo "No formulas to build"
    exit 0
fi

# Remove output folder
#run "rm -rf $OUTPUT_FOLDER"
run "mkdir -p $OUTPUT_FOLDER"

ITER=0
for formula in "${FORMULAS[@]}" ; do
    formula_name="${formula%.*}"

    if [ "$TRAVIS" = true ] ; then
        travis_fold_start "build.$ITER" "Build $formula_name"
        travis_time_start
    fi

    build

    if [ "$TRAVIS" = true ] ; then
        travis_time_finish
        travis_fold_end "build.$ITER"
        ITER=$(expr $ITER + 1)
    fi
done

echo ""
echo ""

