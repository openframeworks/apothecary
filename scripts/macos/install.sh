# Silent update to prevent long logs
brew update >/dev/null


brew install cmake coreutils autoconf automake ccache gtk-doc brotli libtool wget fontconfig bash jq

# brew reinstall libtool

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
