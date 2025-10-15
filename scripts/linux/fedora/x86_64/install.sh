#!/usr/bin/env bash
set -euo pipefail

# ---------- traps ----------
trap 'trapError' ERR
trapError() {
    echo
    echo " ^ Received error ^"
    exit 1
}

# ---------- helpers ----------
isRunning() {
    # NOTE: $1 is expected to be a PID
    if [ "$(uname)" = "Linux" ]; then
        [[ -d "/proc/$1" ]]
    else
        # naive fallback by process name (non-Linux)
        local number
        number=$(ps aux | sed -E 's/[^ ]* +([^ ]*).*/\1/g' | grep -E "^$1$" | wc -l)
        [[ $number -gt 0 ]]
    fi
}

echoDots() {
    # prints dots while PID is alive
    while isRunning "$1"; do
        for _ in $(seq 1 10); do
            echo -ne "."
            if ! isRunning "$1"; then
                printf "\r"
                return
            fi
            sleep 2
        done
        printf "\r                    "
        printf "\r"
    done
}

# ---------- env ----------
echo "GCC Version request: [${GCC:-system default}]"
ACTIONS_CACHE=${ACTIONS_CACHE:-"0"}

# ---------- distro guard ----------
if ! grep -qi '^id=fedora' /etc/os-release; then
    echo "This script is Fedora-specific. Aborting to avoid mixing package managers."
    exit 2
fi

# ---------- base dev toolchain ----------
sudo dnf -y groupinstall "Development Tools"
sudo dnf -y install \
    coreutils gperf cmake ccache dos2unix autoconf automake libtool pkgconf-pkg-config \
    # X11 + input
    libX11-devel libXext-devel libXrandr-devel libXinerama-devel libXcursor-devel libXi-devel \
    # GL stack
    mesa-libGL-devel mesa-libGLU-devel freeglut-devel \
    # Wayland
    wayland-devel libxkbcommon-devel \
    # audio (openFrameworks/rtaudio)
    alsa-lib-devel pulseaudio-libs-devel jack-audio-connection-kit-devel \
    # math/fft
    fftw-devel

# ---------- gcc selection ----------
# Fedora usually provides ONE system GCC (recent). If you truly need pinned versions,
# prefer building from source or using containers. Below:
# - "system" path just ensures gcc/g++ are present and prints versions
# - gcc15 path builds from source (as in your original)

case "${GCC:-system}" in
  gcc15)
    set -x
    sudo dnf -y install \
        bison flex gmp-devel mpfr-devel libmpc-devel texinfo wget \
        gcc gcc-c++ make
    workdir="$(mktemp -d)"
    pushd "$workdir"
    wget https://ftp.gnu.org/gnu/gcc/gcc-15.0.0/gcc-15.0.0.tar.gz
    tar -xvzf gcc-15.0.0.tar.gz
    cd gcc-15.0.0
    ./contrib/download_prerequisites   # pulls gmp/mpfr/mpc if needed (still good to have -devel)
    mkdir build && cd build
    ../configure --prefix=/usr/local/gcc-15 --enable-languages=c,c++ --disable-multilib
    make -j"$(nproc)"
    sudo make install
    popd
    rm -rf "$workdir"
    # prefer PATH shim over distro alternatives for gcc
    if ! grep -q '/usr/local/gcc-15/bin' ~/.bashrc 2>/dev/null; then
        echo 'export PATH=/usr/local/gcc-15/bin:$PATH' >> ~/.bashrc
    fi
    # ensure current shell sees it too
    export PATH=/usr/local/gcc-15/bin:$PATH
    set +x
    ;;

  gcc*|system)
    # just ensure gcc/g++ exist; Fedora generally ships recent GCC
    sudo dnf -y install gcc gcc-c++
    ;;

  *)
    echo "Unknown GCC selector: $GCC"
    exit 3
    ;;
esac

echo "gcc:  $(command -v gcc)";  gcc  --version | head -n1
echo "g++:  $(command -v g++)";  g++  --version | head -n1
echo "cmake:$(command -v cmake)"; cmake --version | head -n1

# ---------- cache-dependent installs ----------
if [ "$ACTIONS_CACHE" -eq 0 ]; then
    # Nothing extra needed beyond the base dnf install above on Fedora.
    :
fi

echo "✨ Fedora toolchain ready."
