# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache wget
# brew reinstall libtool

export PATH="/usr/local/opt/ccache/libexec:$PATH"
