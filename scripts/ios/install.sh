# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils boost-bcp autoconf automake
# brew reinstall libtool
# export PATH="/usr/local/opt/ccache/libexec:$PATH"

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
    fi
fi
