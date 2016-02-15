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

if [ "$TARGET" == "osx" ] || [ "$TARGET" == "ios" ]; then
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
    if [ "$formula_name" == "poco" -a "$TARGET" == "linux64" ]; then
        ./apothecary -t$TARGET update $formula_name
    else
        echo Compiling $formula_name
        if [ "$OPT" != "" -a "$TARGET" != "linux64" ]; then
            ./apothecary -j$PARALLEL -t$TARGET -a$OPT update $formula_name > formula.log 2>&1 &
        else
            ./apothecary -j$PARALLEL -t$TARGET update $formula_name > formula.log 2>&1 &
        fi
        apothecaryPID=$!
        echoDots $apothecaryPID
        wait $apothecaryPID
    fi
done
echo Compressing libraries
cd $ROOT
TARBALL=openFrameworksLibs_${TRAVIS_BRANCH}_$TARGET$OPT.tar.bz2
tar cjf $TARBALL $(ls  | grep -v apothecary | grep -v scripts)
echo Unencrypting key
openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in scripts/id_rsa.enc -out scripts/id_rsa -d
cp scripts/ssh_config ~/.ssh/config
chmod 600 scripts/id_rsa
echo Uploading libraries
scp -i scripts/id_rsa $TARBALL tests@ci.openframeworks.cc:libs/$TARBALL.new
ssh -i scripts/id_rsa tests@ci.openframeworks.cc "mv libs/$TARBALL.new libs/$TARBALL"
rm scripts/id_rsa
