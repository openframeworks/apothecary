#!/usr/bin/env bash
set -euo pipefail

# --- knobs ---
RELEASEVER="${RELEASEVER:-$(rpm -E %fedora)}"    # e.g. 40
SYSROOT="${SYSROOT:-${GITHUB_WORKSPACE:-$PWD}/aarch64-sysroot}"

echo "=== Fedora aarch64 setup ==="
echo "Release: ${RELEASEVER}"
echo "Sysroot: ${SYSROOT}"

if ! grep -qi '^id=fedora' /etc/os-release; then
  echo "This script expects Fedora. Aborting." >&2
  exit 2
fi

dnf -y upgrade
dnf -y groupinstall "Development Tools"
dnf -y install \
  git cmake ninja-build ccache pkgconf-pkg-config \
  autoconf automake libtool gawk bison flex xz which file rsync wget \
  qemu-user-binfmt qemu-user-static \
  aarch64-linux-gnu-gcc aarch64-linux-gnu-g++ binutils-aarch64-linux-gnu || true
dnf -y install \
  gcc-aarch64-linux-gnu gcc-c++-aarch64-linux-gnu binutils-aarch64-linux-gnu || true

rm -rf "${SYSROOT}"
mkdir -p "${SYSROOT}"

dnf -y --releasever="${RELEASEVER}" --installroot="${SYSROOT}" --forcearch=aarch64 \
  --setopt=install_weak_deps=False --nodocs \
  install filesystem bash glibc glibc-langpack-en ca-certificates

# Devel deps for openFrameworks-style native libs (TARGET aarch64)
dnf -y --releasever="${RELEASEVER}" --installroot="${SYSROOT}" --forcearch=aarch64 \
  --setopt=install_weak_deps=False --nodocs install \
  gcc gcc-c++ make pkgconf-pkg-config \
  libX11-devel libXext-devel libXrandr-devel libXinerama-devel libXcursor-devel libXi-devel \
  mesa-libGL-devel mesa-libGLU-devel freeglut-devel \
  wayland-devel libxkbcommon-devel \
  alsa-lib-devel pulseaudio-libs-devel jack-audio-connection-kit-devel \
  fftw-devel \
  mesa-libEGL-devel mesa-libGLES-devel \
  zlib-devel

# Sanity dirs
mkdir -p "${SYSROOT}"/{usr/lib,usr/lib64,usr/include,usr/share}

# --- pkg-config + toolchain env ---
export PKG_CONFIG_SYSROOT_DIR="${SYSROOT}"
export PKG_CONFIG_LIBDIR="${SYSROOT}/usr/lib64/pkgconfig:${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"
export SYSROOT

# Persist to GH env if present
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "SYSROOT=${SYSROOT}"
    echo "PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR}"
    echo "PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR}"
  } >> "${GITHUB_ENV}"
fi

# Optional: emit a CMake toolchain file (shared name across distros)
TOOLCHAIN="${TOOLCHAIN:-${GITHUB_WORKSPACE:-$PWD}/toolchains/aarch64-gcc.cmake}"
mkdir -p "$(dirname "$TOOLCHAIN")"
cat > "$TOOLCHAIN" <<'EOF'
# Generic aarch64 cross toolchain (uses SYSROOT and PKG_CONFIG_* from env)
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
# Root the search in the sysroot
set(CMAKE_SYSROOT "$ENV{SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "$ENV{SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
# Wire pkg-config for cross
set(ENV{PKG_CONFIG_SYSROOT_DIR} "$ENV{SYSROOT}")
set(ENV{PKG_CONFIG_LIBDIR}      "$ENV{PKG_CONFIG_LIBDIR}")
EOF

echo "CMake toolchain: $TOOLCHAIN"
[[ -n "${GITHUB_ENV:-}" ]] && echo "CMAKE_TOOLCHAIN_FILE=$TOOLCHAIN" >> "$GITHUB_ENV"

echo "Listing a few .pc files in sysroot:"
find "${SYSROOT}/usr/lib64/pkgconfig" -maxdepth 1 -name '*.pc' 2>/dev/null | head -n 20 || true

echo "Fedora aarch64 setup complete."
