#!/usr/bin/env bash
set -e
set -o pipefail

bash "$(dirname "${BASH_SOURCE[0]}")/../apple-install-tools.sh" cmake coreutils autoconf automake ccache gtk-doc brotli libtool wget fontconfig bash shfmt gum

# brew reinstall libtool

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
