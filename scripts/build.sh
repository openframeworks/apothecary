#!/usr/bin/env bash
set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

ROOT=$(cd $(dirname "$0"); pwd -P)/..
APOTHECARY_PATH=$ROOT/apothecary

cd $APOTHECARY_PATH

# trap any script errors and exit
trap "trapError" ERR

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
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return;
            fi
            sleep 2
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
        PARALLEL=1
    fi
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

if [ "$TARGET" == "emscripten" ]; then
    source ~/emscripten-sdk/emsdk_env.sh
fi

echo "Running apothecary from $PWD"
ITER=0
for formula in openssl $( ls -1 formulas | grep -v _depends | grep -v openssl | grep -v libpng | grep -v zlib | grep -v libxml2 ) ; do
    
    formula_name="${formula%.*}"

    travis_fold_start "build.$ITER" "Build $formula_name"
    travis_time_start

    if [ "$OPT" != "" -a "$TARGET" != "linux64" ]; then
        echo Compiling $formula_name
        echo "./apothecary -f -j$PARALLEL -t$TARGET -a$OPT update $formula_name" > formula.log 2>&1
        ./apothecary -f -j$PARALLEL -t$TARGET -a$OPT update $formula_name >> formula.log 2>&1 &
    elif [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ] || [ "$TARGET" == "osx" ]; then
        # compile everything but poco openssl curl assimp opencv and svg tiny
        if [ "$OPT2" == "1" ]; then
            if [ "$formula_name" != "poco" ] && [ "$formula_name" != "openssl" ] && ["$formula_name" != "curl" ] && [ "$formula_name" != "assimp" ] && [ "$formula_name" != "opencv" ] && [ "$formula_name" != "svgtiny" ]; then
                echo Pass 1 - Compiling $formula_name
                echo "./apothecary -f -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
                ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
            else 
                echo "Skipped $formula_name" > formula.log 2>&1
            fi
        # only compile poco, openssl, curl
        elif [ "$OPT2" == "2" ]; then
            if [ "$formula_name" == "poco" ] || [ "$formula_name" == "openssl" ] || [ "$formula_name" == "curl" ]; then
                echo Pass 2 - Compiling $formula_name
                echo "./apothecary -f -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
                ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
            else 
                echo "Skipped $formula_name" > formula.log 2>&1
            fi
        # only compile assimp, opencv, svgtiny
        elif [ "$OPT2" == "3" ]; then
            if [ "$formula_name" == "assimp" ] || [ "$formula_name" == "opencv" ] || [ "$formula_name" == "svgtiny" ]; then
                echo Pass 3 - Compiling $formula_name
                echo "./apothecary -f -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
                ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
            else 
                echo "Skipped $formula_name" > formula.log 2>&1
            fi
        else
            echo Compiling $formula_name
            echo "./apothecary -f -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
            ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
        fi
    elif [ "$TARGET" == "vs" ]; then
        echo Compiling $formula_name
        echo "./apothecary -j$PARALLEL -t$TARGET -a$ARCH update $formula_name" > formula.log 2>&1
        ./apothecary -f -j$PARALLEL -t$TARGET -a$ARCH update $formula_name >> formula.log 2>&1 &
    elif [ "$TARGET" == "msys2" ]; then
        echo Compiling $formula_name
        echo "./apothecary -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
        ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
    else
        echo Compiling $formula_name
        echo "./apothecary -f -j$PARALLEL -t$TARGET update $formula_name" > formula.log 2>&1
        ./apothecary -f -j$PARALLEL -t$TARGET update $formula_name >> formula.log 2>&1 &
    fi

    apothecaryPID=$!
    echoDots $apothecaryPID
    wait $apothecaryPID

    echo "Tail of log for $formula_name"    
    tail -n 30 formula.log    

    end=`date +%s`
    runtime=$((end-start))
    
    travis_time_finish
    travis_fold_end "build.$ITER"
    

    ITER=$(expr $ITER + 1)
done

if [[ "$TRAVIS_BRANCH" == "master" && "$TRAVIS_PULL_REQUEST" == "false" ]] || [ ! -z ${APPVEYOR+x} ]; then
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

cd $ROOT
echo "Compressing libraries from $PWD"
LIBS=$(ls | grep -v \.appveyor.yml | grep -v \.travis.yml | grep -v \.gitignore | grep -v apothecary | grep -v scripts)
if [ ! -z ${APPVEYOR+x} ]; then
	TARBALL=openFrameworksLibs_${APPVEYOR_REPO_BRANCH}_${TARGET}${VS_NAME}_${ARCH}.zip
	7z a $TARBALL $LIBS
else
	TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_$TARGET$OPT$OPT2.tar.bz2
	tar cjf $TARBALL $LIBS
	echo Unencrypting key
	openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in scripts/id_rsa.enc -out scripts/id_rsa -d
	cp scripts/ssh_config ~/.ssh/config
	chmod 600 scripts/id_rsa
	echo Uploading libraries
	scp -i scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
	ssh -i scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
	rm scripts/id_rsa
fi
