# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache pkg-config
# brew reinstall libtool

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
