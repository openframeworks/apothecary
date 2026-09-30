#!/usr/bin/env bash
set -e

# Silent update to prevent long logs

if ! which realpath >&/dev/null; then
  if ! which brew >&/dev/null; then
    msg="ERROR: This script requires brew. See https://brew.sh for installation instructions."
    echo "$(tput setaf 1)$msg$(tput sgr0)" >&2
    exit 1
  fi
fi

brew update >/dev/null
formulae=(cmake coreutils autoconf automake gtk-doc brotli libtool wget fontconfig bash shfmt wget2 curl gum)
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  # Keep the runner's working tools instead of upgrading their dependency trees.
  export HOMEBREW_NO_INSTALL_UPGRADE=1
  export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
  # ccache is optional in build.sh. Installing it from source on older macOS
  # pulls in Rust/LLVM and can fail before any Apothecary formula is built.
else
  formulae+=(ccache)
fi
brew install --formula "${formulae[@]}"

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
