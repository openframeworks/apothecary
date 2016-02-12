set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

ROOT=$(dirname "$0")/..
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

echoDots(){
    while [ -d /proc/$1 ]; do
        for i in $(seq 1 10); do 
            echo -ne .
            sleep 2
        done
        printf "\r                    "
        printf "\r"
    done
}

for formula in $( ls -1 formulas | grep -v _depends) ; do
    formula_name="${formula%.*}"
    echo Compiling $formula_name
    if [ "$OPT" != "" ]; then
        ./apothecary -$TARGET -a$OPT update $formula_name #> formula.log 2>&1 &
    else
        ./apothecary -$TARGET update $formula_name #> formula.log 2>&1 &
    fi
    #apothecaryPID=$!
    #echoDots $apothecaryPID
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
