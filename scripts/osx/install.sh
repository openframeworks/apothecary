# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache
brew reinstall libtool
export PATH="/usr/local/opt/ccache/libexec:$PATH"
xcode-select -switch /Applications/Xcode-12.2.app
