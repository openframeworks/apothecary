#!/usr/bin/env bash
set -e

# Reuse runner tools and avoid upgrades/source builds in the artifact finalizer.
bash "$(dirname "${BASH_SOURCE[0]}")/../apple-install-tools.sh" \
  cmake coreutils autoconf automake ccache gtk-doc brotli libtool wget fontconfig bash jq gum

# brew reinstall libtool

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
