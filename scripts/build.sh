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

if [ "$TARGET" == "osx" ] || [ "$TARGET" == "ios" ] || [ "$TARGET" == "tvos" ]; then
    PARALLEL=4
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

for formula in $( ls -1 formulas | grep -v _depends) ; do
    formula_name="${formula%.*}"
    echo Compiling $formula_name
    if [ "$OPT" != "" -a "$TARGET" != "linux64" ]; then
        ./apothecary -j$PARALLEL -t$TARGET -a$OPT update $formula_name > formula.log 2>&1 &
    else
        ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
    fi
    apothecaryPID=$!
    echoDots $apothecaryPID
    wait $apothecaryPID
done

if [[ $TRAVIS_PULL_REQUEST == "true" ]]; then
    # exit here on PR's 
    echo "This is a PR exiting build before compressing";
    exit 0
else 
    echo "On Master Branch and not a PR";
fi

if [[ $TRAVIS_SECURE_ENV_VARS == "false" ]]; then 
    echo "No secure vars set so exiting before compressing";
    exit 0
fi

echo Compressing libraries
cd $ROOT
TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_$TARGET$OPT.tar.bz2
tar cjf $TARBALL $(ls  | grep -v apothecary | grep -v scripts)

if [[ $TRAVIS_BRANCH == "master" && $TRAVIS_PULL_REQUEST == "false" ]]; then
    echo "On Master Branch";
    # only on master
    echo Unencrypting key
    openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in scripts/id_rsa.enc -out scripts/id_rsa -d
    cp scripts/ssh_config ~/.ssh/config
    chmod 600 scripts/id_rsa
    echo Uploading libraries
    scp -i scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
    ssh -i scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
    rm scripts/id_rsa
fi


