# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake
brew reinstall libtool
