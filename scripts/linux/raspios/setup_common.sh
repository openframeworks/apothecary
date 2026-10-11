#!/usr/bin/env bash
# Shared host + sysroot setup for Raspberry Pi slices.
# Required: RPI_SLICE DEB_ARCH GCC_TRIPLE QEMU_STATIC NATIVE_UNAME DEFAULT_SYSROOT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sysroot_utils.sh
source "$SCRIPT_DIR/sysroot_utils.sh"

: "${RPI_SLICE:?}"
: "${DEB_ARCH:?}"
: "${GCC_TRIPLE:?}"
: "${QEMU_STATIC:?}"
: "${NATIVE_UNAME:?}"
: "${DEFAULT_SYSROOT:?}"

CROSS_OS="${CROSS_OS:-bookworm}"
CROSS_OS="${CROSS_OS,,}"
DEBIAN_MIRROR="${DEBIAN_MIRROR:-http://deb.debian.org/debian}"
SYSROOT="${SYSROOT:-$DEFAULT_SYSROOT}"
TOOLCHAIN_ROOT="${TOOLCHAIN_ROOT:-/usr}"
RPI_QEMU_ARCH="${RPI_QEMU_ARCH:-$RPI_SLICE}"
QEMU_BINFMT="${QEMU_BINFMT:-${QEMU_STATIC%-static}}"

if [[ "$CROSS_OS" != "bookworm" ]]; then
    echo "Unsupported CROSS_OS '$CROSS_OS' (official Raspberry Pi sysroot is bookworm)." >&2
    exit 1
fi

if rpi_is_native && [[ "$(uname -m)" == "$NATIVE_UNAME" ]]; then
    echo "Detected Raspberry Pi OS on $NATIVE_UNAME. Using native root as SYSROOT."
    SYSROOT="/"
    NATIVE=true
else
    NATIVE=false
fi

export SYSROOT TOOLCHAIN_ROOT NATIVE RPI_QEMU_ARCH GCC_TRIPLE

if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must run as root (sudo)." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
HOST_PACKAGES=(
    ca-certificates
    curl
    pkg-config
    libwayland-bin # Native wayland-scanner generates code for the target build.
    build-essential
    cmake
    ninja-build
    autoconf
    automake
    libtool
    flex
    bison
    gawk
    python3
    xz-utils
    git
)
if [[ "$NATIVE" != "true" ]]; then
    HOST_PACKAGES+=(
        debootstrap
        debian-archive-keyring
        qemu-user-static
        binfmt-support
        "gcc-10-${GCC_TRIPLE}"
        "g++-10-${GCC_TRIPLE}"
        "binutils-${GCC_TRIPLE}"
        python3-pip
        gnupg
    )
fi
apt-get update
apt-get install -y --no-install-recommends "${HOST_PACKAGES[@]}"

if [[ "$NATIVE" != "true" ]]; then
    update-binfmts --enable "$QEMU_BINFMT" >/dev/null 2>&1 || true
fi

if [[ "$NATIVE" == "true" ]]; then
    echo "Native setup complete. SYSROOT=/"
else
    echo "Building Raspberry Pi $RPI_SLICE sysroot at $SYSROOT ($CROSS_OS $DEB_ARCH)"
    mkdir -p "$(dirname "$SYSROOT")"
    local_libc="$(rpi_libc_path "$SYSROOT" "$GCC_TRIPLE")"
    if [[ -d "$SYSROOT/debootstrap" && ! -f "$local_libc" ]]; then
        echo "Incomplete debootstrap leftover in $SYSROOT; rebuilding."
        rm -rf "$SYSROOT"
    fi
    if [[ ! -f "$local_libc" ]]; then
        rm -rf "$SYSROOT"
        mkdir -p "$SYSROOT"
        rpi_debootstrap_bookworm "$DEB_ARCH" "$SYSROOT" "$QEMU_STATIC"
    else
        echo "Reusing existing sysroot at $SYSROOT"
        rpi_copy_qemu "$SYSROOT" "$QEMU_STATIC"
    fi
fi

if [[ "$NATIVE" != "true" ]]; then
    if [[ ! -x "/usr/bin/${GCC_TRIPLE}-gcc-10" ]]; then
        echo "${GCC_TRIPLE}-gcc-10 not found after install." >&2
        exit 1
    fi
    "${GCC_TRIPLE}-gcc-10" --version | head -1
    test "$("${GCC_TRIPLE}-gcc-10" -dumpversion | cut -d. -f1)" = "10"
    if ! cmake --version 2>/dev/null | grep -qE 'cmake version 3\.(2[2-9]|[3-9]|[0-9]{2,})'; then
        python3 -m pip install --no-cache-dir 'cmake==3.31.6'
    fi
    cmake --version | head -1
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
    {
        echo "SYSROOT=$SYSROOT"
        echo "TOOLCHAIN_ROOT=$TOOLCHAIN_ROOT"
        echo "TOOLCHAIN_PREFIX=$GCC_TRIPLE"
        echo "GCC=gcc10"
        echo "GCC_VERSION=10"
        echo "NATIVE=$NATIVE"
        echo "RPI_QEMU_ARCH=$RPI_QEMU_ARCH"
        echo "PKG_CONFIG_SYSROOT_DIR=$SYSROOT"
        echo "PKG_CONFIG_LIBDIR=$SYSROOT/usr/lib/${GCC_TRIPLE}/pkgconfig:$SYSROOT/usr/share/pkgconfig"
        echo "PKG_CONFIG_PATH="
    } >>"$GITHUB_ENV"
    if [[ "$NATIVE" == "true" ]]; then
        echo "CC=gcc-10" >>"$GITHUB_ENV"
        echo "CXX=g++-10" >>"$GITHUB_ENV"
    else
        echo "CC=${GCC_TRIPLE}-gcc-10" >>"$GITHUB_ENV"
        echo "CXX=${GCC_TRIPLE}-g++-10" >>"$GITHUB_ENV"
    fi
fi

echo "=== raspios $RPI_SLICE setup complete ==="
echo "SYSROOT=$SYSROOT"
echo "TOOLCHAIN_ROOT=$TOOLCHAIN_ROOT"
echo "NATIVE=$NATIVE"
