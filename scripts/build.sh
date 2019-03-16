#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

if [ "$TRAVIS" = true ] && [ "$TARGET" == "emscripten" ]; then
    run(){
        docker exec -it emscripten sh -c "TARGET=\"emscripten\" $@"
    }
    CCACHE_DOCKER=$(docker exec -it emscripten ccache -p | grep "cache_dir =" | sed "s/(default) cache_dir = \(.*\)/\1/") | sed s/\r//
    ROOT=$(docker exec -it emscripten pwd) | sed s/\r//
else
    run(){
        @$
    }
    ROOT=$(cd $(dirname "$0"); pwd -P)/..
fi

APOTHECARY_PATH=$ROOT/apothecary
OUTPUT_FOLDER=$ROOT/out
# VERBOSE=true

if [ -z $TARGET ] ; then
    echo "Environment variable TARGET not defined. Should be target os"
    exit 1
fi

echo "Running apothecary from $PWD"
echo "Target: $TARGET"
echo "Architecture: $ARCH"
echo "Bundle: $BUNDLE"

FORMULAS=(
    # Dependencies for other formulas (cairo)
    "pixman"
    "pkg-config"
    "zlib"

    # All formulas
    "assimp"
    "boost"
    "FreeImage"
    "libpng"
    "libxml2"
    "freetype"
    "fmodex"
    "glew"
    "glfw"
    "glm"
    "json"
    "libusb"
    "kiss"
    "opencv"
    "openssl"
    "portaudio"
    "pugixml"
    "utf8"
    "videoInput"
    "rtAudio"
    "tess2"
    "uriparser"

    # Formulas with depenencies in the end
    "curl"
    "poco"
    "svgtiny"
    "uri"
    "cairo"
)

# Seperate in bundles on osx
if [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ] || [ "$TARGET" == "osx" ] || [ "$TARGET" == "vs" ]; then
    if [ "$BUNDLE" == "1" ]; then
        FORMULAS=(
            # Dependencies for other formulas (cairo)
            "pixman"
            "pkg-config"
            "zlib"
            "libpng"
            "freetype"

            # All formulas
            "boost"
            "FreeImage"
            "fmodex"
            "glew"
            "glfw"
            "glm"
            "json"
            "libusb"
            "kiss"
            "portaudio"
            "pugixml"
            "utf8"
            "videoInput"
            "rtAudio"
            "tess2"
            "uriparser"

            # Formulas with depenencies in the end
            "cairo"
            "uri"
        )
    elif [ "$BUNDLE" == "2" ]; then
        FORMULAS=(
            "openssl"
            "poco"
            "curl"
        )
    elif [ "$BUNDLE" == "3" ]; then
        FORMULAS=(
            "assimp"
            "libxml2"
            "svgtiny"
        )
    elif [ "$BUNDLE" == "4" ]; then
        FORMULAS=(
            "opencv"
        )
    fi
fi

# trap any script errors and exit
# trap "trapError" ERR

trapError() {
	echo
	echo " ^ Received error building $formula_name ^"
	cat formula.log
	if [ "$formula_name" == "boost" ]; then
	    cat $APOTHECARY_PATH/build/boost/bootstrap.log
	fi
    if [ -f $APOTHECARY_PATH/build/$formula_name/config.log ]; then
        tail -n1000 $APOTHECARY_PATH/build/$formula_name/config.log
    fi
	exit 1
}

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
    if [ "$TARGET" == "osx" ]; then
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
    fi

    if [ "$TRAVIS" = true ] && [ "$TARGET" == "emscripten" ]; then
        docker exec -it emscripten sh -c 'echo $HOME'
        docker cp /home/travis/.ccache emscripten:$CCACHE_DOCKER
    fi

    ccache -z
    run "ccache -z"
    run "ccache -s"
fi

if [ "$TARGET" == "linux" ]; then
    TARGET="linux64"
    if [ "$OPT" == "gcc5" ]; then
        export CC="gcc-5"
        export CXX="g++-5 -std=c++11"
        export COMPILER="g++5 -std=c++11"
    elif [ "$OPT" == "gcc6" ]; then
        export CC="gcc-6 -fPIE"
        export CXX="g++-6 -std=c++11 -fPIE"
        export COMPILER="g++6 -std=c++11 -fPIE"
    fi
fi

function build(){
    trap "trapError" ERR

    echo Build $formula_name

    local ARGS="-f -j$PARALLEL -p -t$TARGET -d$OUTPUT_FOLDER "
    if [ "$ARCH" != "" ] ; then
        ARGS="$ARGS -a$ARCH"
    fi

    if [ "$VERBOSE" = true ] ; then
        echo "./apothecary $ARGS update $formula_name"
        run "cd $APOTHECARY_PATH;./apothecary $ARGS update $formula_name"
    else
        echo "./apothecary $ARGS update $formula_name > formula.log 2>&1"
        run "cd $APOTHECARY_PATH;./apothecary $ARGS update $formula_name >> formula.log 2>&1" &

        apothecaryPID=$!
        echoDots $apothecaryPID
        wait $apothecaryPID

        echo "Tail of log for $formula_name"
        run "tail -n 100 formula.log"
    fi

}

# Remove output folder
run "rm -rf $OUTPUT_FOLDER"
run "mkdir $OUTPUT_FOLDER"

ITER=0
for formula in "${FORMULAS[@]}" ; do

# for formula in openssl $( ls -1 formulas | grep -v _depends | grep -v openssl | grep -v libpng | grep -v zlib | grep -v libxml2 ) ; do

    formula_name="${formula%.*}"

    if [ "$TRAVIS" = true ] ; then
        travis_fold_start "build.$ITER" "Build $formula_name"
        travis_time_start
    fi

    trap "trapError" ERR
    run "scripts/build_one.sh"

    if [ "$TRAVIS" = true ] ; then
        travis_time_finish
        travis_fold_end "build.$ITER"
        ITER=$(expr $ITER + 1)
    fi
done

echo ""
echo ""


if [ "$TRAVIS" = true ] && [ "$TARGET" == "emscripten" ]; then
    docker cp emscripten:$CCACHE_DOCKER /home/travis/.ccache
    docker cp emscripten:/root/.emscripten_cache /home/travis/.emscripten_cache
fi

if  type "ccache" > /dev/null; then
    echo $(ccache -s)
fi

if [[ "$TRAVIS_BRANCH" == "master" && "$TRAVIS_PULL_REQUEST" == "false" ]] || [[ ! -z ${APPVEYOR+x} && -z ${APPVEYOR_PULL_REQUEST_NUMBER+x} ]]; then
    # exit here on PR's
    echo "On Master Branch and not a PR";
else
    echo "This is a PR or not master branch, exiting build before compressing";
    exit 0
fi

if [[ $TRAVIS_SECURE_ENV_VARS == "false" ]]; then
    echo "No secure vars set so exiting before compressing";
    exit 0
fi

echo "Compressing libraries from $OUTPUT_FOLDER"
LIBS=$(run "ls $OUTPUT_FOLDER")

if [ ! -z ${APPVEYOR+x} ]; then
	TARBALL=${ROOT}/openFrameworksLibs_${APPVEYOR_REPO_BRANCH}_${TARGET}${VS_NAME}_${ARCH}_${BUNDLE}.zip
	7z a $TARBALL $LIBS
elif [ "$TRAVIS" = true ]
	TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_$TARGET$OPT$ARCH$BUNDLE.tar.bz2
	run "cd $OUTPUT_FOLDER; tar cjf $TARBALL $LIBS"
    if [ "$TARGET" == "emscripten" ]; then
        docker cp ${OUTPUT_FOLDER}/${TARBALL} .
    fi
	echo Unencrypting key
	openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in $ROOT/scripts/id_rsa.enc -out $ROOT/scripts/id_rsa -d
	cp $ROOT/scripts/ssh_config ~/.ssh/config
	chmod 600 $ROOT/scripts/id_rsa
	echo Uploading libraries
	scp -i $ROOT/scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
	ssh -i $ROOT/scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
	rm $ROOT/scripts/id_rsa
fi
