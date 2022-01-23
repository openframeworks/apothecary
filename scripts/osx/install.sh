# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache gtk-doc brotli
# brew reinstall libtool

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
