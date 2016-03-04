brew install cmake

set -e
# capture failing exits in commands obscured behind a pipe
set -o pipefail

APOTH=$(cd $(dirname "$0"); pwd -P)/../..
APOTHECARY_PATH=$APOTH/apothecary
cd $APOTHECARY_PATH

if [ "$TARGET" == "tvos" ]; then
    if [ "$OPT2" == "1" ]; then
        echo "Install - 1"
    elif [ "$OPT2" == "2" ]; then
        echo "Install - 2"
        ./apothecary -t tvos download poco
        ./apothecary -t tvos download openssl
    fi
fi
