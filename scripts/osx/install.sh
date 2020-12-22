# Silent update to prevent long logs
brew update >/dev/null

brew install cmake coreutils autoconf automake ccache
brew reinstall libtool

sudo xcode-select -switch $DEVELOPER_DIR

local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
echo "SDK PATH IS ${SDK_PATH}"

export PATH="/usr/local/opt/ccache/libexec:$PATH"
