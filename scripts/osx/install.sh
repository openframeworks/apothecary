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
formulae=(cmake coreutils autoconf automake brotli libtool wget fontconfig bash shfmt curl gum)
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  # Keep the runner's working tools instead of upgrading their dependency trees.
  export HOMEBREW_NO_INSTALL_UPGRADE=1
  export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
  # ccache is optional in build.sh. Installing it from source on older macOS
  # pulls in Rust/LLVM and can fail before any Apothecary formula is built.
  # GTK documentation is disabled in the Apple build. wget2 is optional;
  # the downloader also supports curl and wget. Avoid their source build trees.
  missing_formulae=()
  for formula in "${formulae[@]}"; do
    # NO_INSTALL_UPGRADE still returns an error for an outdated installed
    # formula. Exclude installed formulae instead of asking brew to install them.
    if brew list --formula --versions "$formula" >/dev/null 2>&1; then
      echo "Using installed Homebrew formula: $formula"
    else
      missing_formulae+=("$formula")
    fi
  done
  formulae=("${missing_formulae[@]}")
else
  formulae+=(ccache gtk-doc wget2)
fi
if [[ ${#formulae[@]} -gt 0 ]]; then
  brew install --formula "${formulae[@]}"
fi

ls -n /Applications/ | grep Xcode

export PATH="/usr/local/opt/ccache/libexec:$PATH"
