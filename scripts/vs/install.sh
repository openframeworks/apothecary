#!/usr/bin/env bash
set -e

if ! command -v winget &>/dev/null; then
    REQUIRED_WINGET=("Microsoft.WindowsTerminal" "Ninja-build.Ninja" "jqlang.jq")
    for pkg in "${REQUIRED_WINGET[@]}"; do
        if winget list --id "$pkg" &>/dev/null; then
            INST=true
            #echo "$pkg is already installed."
        else
            winget install -e --id "$pkg"
        fi
    done
fi

# BASH / WASL setup:
is_installed() {
    dpkg -s "$1" &>/dev/null
}
if grep -qi microsoft /proc/version; then
    REQUIRED_PKGS=("shasum" "unzip" "autoconf" "libtool" "automake" "dos2unix" "ccache" "cmake" "build-essential")
    sudo apt update
    for pkg in "${REQUIRED_PKGS[@]}"; do
        is_installed "$pkg" || sudo apt install -y "$pkg"
    done
fi