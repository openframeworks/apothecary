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
	echo " ^ Received error ^"
	cat formula.log
	if [ "$formula_name" == "boost" ]; then
	    cat $APOTHECARY_PATH/build/boost/bootstrap.log
	fi
	exit 1
}

isRunning(){
    if [ “$(uname)” == “Darwin” ]; then
        number=$(ps aux | sed -E "s/[^ ]* +([^ ]*).*/\1/g" | grep ^$1$ | wc -l)

        if [ $number -gt 0 ]; then
            return 0;
        else
            return 1;
        fi
    elif [ “$(uname)” == “Linux” ]; then
	if [ -d /proc/$1 ]; then
	    return 0
        else
            return 1
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

if [ "$TARGET" == "osx" ]; then
    PARALLEL=4
elif [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ]; then
    PARALLEL=2
elif [ "$TARGET" == "android" ]; then
    PARALLEL=2
else
    PARALLEL=1
fi

if [ "$TARGET" == "linux" ]; then
    TARGET="linux64"
    if [ "$OPT" == "gcc5" ]; then
        export CC="gcc-5" 
        export CXX="g++-5"
    fi
fi

if [ "$TARGET" == "emscripten" ]; then
    source ~/emscripten-sdk/emsdk_env.sh
fi

for formula in "openssl $( ls -1 formulas | grep -v _depends | grep -v openssl )" ; do
    formula_name="${formula%.*}"
    if [ "$OPT" != "" -a "$TARGET" != "linux64" ]; then
        echo Compiling $formula_name
        ./apothecary -j$PARALLEL -t$TARGET -a$OPT update $formula_name > formula.log 2>&1 &
    elif [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ]; then
        if [ "$OPT2" == "1" ]; then
            if [ "$formula_name" != "poco" ] && [ "$formula_name" != "openssl" ]; then
                echo Pass 1 - Compiling $formula_name
                ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
            fi
        elif [ "$OPT2" == "2" ]; then
            if [ "$formula_name" == "poco" ] || [ "$formula_name" == "openssl" ]; then
                echo Pass 2 - Compiling $formula_name
                ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
            fi
        else
            echo Compiling $formula_name
            ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
        fi
    else
        echo Compiling $formula_name
        ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
    fi
    apothecaryPID=$!
    echoDots $apothecaryPID
    wait $apothecaryPID
done

if [ $TRAVIS_BRANCH == "master" ] && [ $TRAVIS_PULL_REQUEST == "false" ]; then
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

echo Compressing libraries
cd $ROOT
TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_$TARGET$OPT$OPT2.tar.bz2
tar cjf $TARBALL $(ls  | grep -v apothecary | grep -v scripts)

echo Unencrypting key
openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in scripts/id_rsa.enc -out scripts/id_rsa -d
cp scripts/ssh_config ~/.ssh/config
chmod 600 scripts/id_rsa
echo Uploading libraries
scp -i scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
ssh -i scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
rm scripts/id_rsa


