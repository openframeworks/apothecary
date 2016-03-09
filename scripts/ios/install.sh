brew install cmake 2>/dev/null

set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

APOTH=$(cd $(dirname "$0"); pwd -P)/../..
APOTHECARY_PATH=$APOTH/apothecary
cd $APOTHECARY_PATH

if [ "$TARGET" == "ios" ]; then
    if [ "$OPT2" == "1" ]; then
        echo "Install - 1"
    elif [ "$OPT2" == "2" ]; then
        echo "Install - 2"
        ./apothecary -t ios download poco
        ./apothecary -t ios download openssl
    fi
fi
