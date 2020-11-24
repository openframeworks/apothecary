# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache
brew reinstall libtool
export PATH="/usr/local/opt/ccache/libexec:$PATH"
export DEVELOPER_DIR="/Applications/Xcode-12.2.app/Contents/Developer"
echo "xcode select sdk path is $(xcode-select -p)"
echo "xcrun find ld path is $(xcrun -f ld)"
echo "xcrun show sdk path is $(xcrun --show-sdk-path)"
