#!/usr/bin/env bash
# Called by Apple install scripts with their required Homebrew formula list.
set -euo pipefail
formulae=("$@")
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    # Keep the runner image's tools; an update/upgrade can bootstrap LLVM/Rust
    # from source on older macOS before any library cache is restored.
    export HOMEBREW_NO_AUTO_UPDATE=1
    export HOMEBREW_NO_INSTALL_UPGRADE=1
    export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
    missing_formulae=()
    for formula in "${formulae[@]}"; do
        case "$formula" in
            ccache|gtk-doc|wget2) continue ;; # optional tools, costly source trees
        esac
        if brew list --formula --versions "$formula" >/dev/null 2>&1; then
            echo "Using installed Homebrew formula: $formula"
        else
            missing_formulae+=("$formula")
        fi
    done
    formulae=("${missing_formulae[@]}")
else
    brew update >/dev/null
fi
if [[ ${#formulae[@]} -gt 0 ]]; then
    brew install --formula "${formulae[@]}"
fi
