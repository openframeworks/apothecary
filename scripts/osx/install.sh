# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache
brew reinstall libtool

sudo xcode-select -switch "/Applications/Xcode_12.2.app/Contents/Developer"

export PATH="/usr/local/opt/ccache/libexec:$PATH"
