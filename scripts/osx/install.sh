#!/usr/bin/env bash
# Silent update to prevent long logs

if ! which realpath >&/dev/null; then
  if ! which brew >&/dev/null; then
    msg="ERROR: This script requires brew. See https://brew.sh for installation instructions."
    echo "$(tput setaf 1)$msg$(tput sgr0)" >&2
    exit 1
  fi
fi

brew update >/dev/null
brew install cmake coreutils autoconf automake ccache gtk-doc brotli libtool wget fontconfig bash shfmt wget2 curl

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
