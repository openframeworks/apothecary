#!/usr/bin/env bash
set -e

# trap any script errors and exit
trap "trapError" ERR

trapError() {
    echo
    echo " ^ Received error ^"
    exit 1
}

isRunning() {
    if [ “$(uname)” == “Linux” ]; then
        if [ -d /proc/$1 ]; then
            return 0
        else
            return 1
        fi
    else
        number=$(ps aux | sed -E "s/[^ ]* +([^ ]*).*/\1/g" | grep ^$1$ | wc -l)

        if [ $number -gt 0 ]; then
            return 0
        else
            return 1
        fi
    fi
}

echoDots() {
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return
            fi
            sleep 2
        done
        printf "\r                    "
        printf "\r"
    done
}

echo "GCC Version: [$GCC]"
sudo apt-get update
sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu binutils-aarch64-linux-gnu
sudo apt-get update
sudo apt-get install -y qemu-user-static binfmt-support
if command -v docker &>/dev/null; then
    docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
fi
if [[ "$GCC" =~ ^gcc(8|9|10|11|12|13)$ ]]; then
    GCC_VERSION=${BASH_REMATCH[1]}
    sudo apt update
    sudo apt install software-properties-common
    sudo add-apt-repository ppa:ubuntu-toolchain-r/test
    sudo apt update
    sudo apt install -y --allow-unauthenticated gcc-${GCC_VERSION} g++-${GCC_VERSION}
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-${GCC_VERSION} ${GCC_VERSION} \
        --slave /usr/bin/g++ g++ /usr/bin/g++-${GCC_VERSION}
    sudo apt-get install -y gperf coreutils libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev libc6-dev
    sudo update-alternatives --config gcc
    gcc --version
    g++ -v
elif [ "$GCC" == "gcc14" ]; then
    # https://gcc.gnu.org/gcc-14/changes.html
    sudo apt update
    sudo apt install -y software-properties-common
    # Add the Ubuntu Toolchain PPA for newer GCC versions
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt update
    sudo apt install -y --allow-unauthenticated gcc-14 g++-14
    # Configure alternatives to set GCC 14 as default
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 14 \
        --slave /usr/bin/g++ g++ /usr/bin/g++-14
    sudo update-alternatives --config gcc # GCC 14 as the default
    gcc --version
    g++ -v
elif [ "$GCC" == "gcc15" ]; then
    # https://gcc.gnu.org/gcc-15/changes.html

    sudo apt update
    sudo apt install -y build-essential flex bison libgmp-dev libmpc-dev libmpfr-dev texinfo wget
    sudo apt-get install -y gperf coreutils libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev libc6-dev

    wget https://ftp.gnu.org/gnu/gcc/gcc-15.0.0/gcc-15.0.0.tar.gz
    tar -xvzf gcc-15.0.0.tar.gz
    cd gcc-15.0.0

    mkdir build
    cd build

    ../configure --prefix=/usr/local/gcc-15 --enable-languages=c,c++ --disable-multilib

    make -j
    sudo make install

    echo "export PATH=/usr/local/gcc-15/bin:\$PATH" >>~/.bashrc
    source ~/.bashrc
    # sudo apt update
    # sudo apt install -y software-properties-common
    # # Add the Ubuntu Toolchain PPA for newer GCC versions
    # sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    # sudo apt update
    # sudo apt install -y gcc-15 g++-15 # Install experimental GCC and G++ version 15
    # # Configure alternatives to set GCC 15 as default
    # sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-15 15 \
    #                          --slave /usr/bin/g++ g++ /usr/bin/g++-15
    # sudo update-alternatives --config gcc  # GCC 15 as the default
    # gcc --version
    # g++ -v

else
    echo "GCC version not specified on OPT env var, set one of gcc14, gcc6 or gcc13"
fi

sudo apt-get -y install libasound-dev libjack-dev libpulse-dev oss4-dev #rtaudio

sudo apt-get update && sudo apt-get install -y autoconf libtool automake dos2unix
sudo apt-get update && sudo apt-get install -y cmake build-essential
sudo apt-get update && sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libglx-dev libgl-dev mesa-common-dev libgl1-mesa-dev libglx-dev

sudo apt-get install -y aptitude build-essential gawk gcc g++ gfortran git texinfo bison libncurses-dev cmake unzip pkg-config flex openssl pigz autoconf automake tar figlet xz-utils libtool dos2unix
sudo apt-get install -y libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev libxrandr-dev libxinerama-dev libx11-dev libxext-dev libxcursor-dev libxi-dev ccache
sudo aptitude install -y gperf

sudo apt-get install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu

sudo apt-get install \
    libboost-iostreams1.83.0:arm64 \
    libcwidget4:arm64 \
    libsigc++-2.0-0v5:arm64 \
    libxapian30:arm64 \
    libasound2-plugins:arm64 \
    libosmesa6:arm64 \
    libpcsclite1:arm64 \
    libspeexdsp1:arm64 \
    libwine:arm64 \
    libxkbregistry0:arm64 \
    libz-mingw-w64:arm64 \
    wine:arm64 \
    wine64:arm64 \
    wget2:arm64 \
    make:arm64 \
    libjack-jackd2-0:arm64 \
    libjack-jackd2-dev:arm64 \
    freeglut3-dev:arm64 \
    libasound2-dev:arm64 \
    libxmu-dev:arm64 \
    libxxf86vm-dev:arm64 \
    g++:arm64 \
    libgl1-mesa-dev:arm64 \
    libglu1-mesa-dev:arm64 \
    libraw1394-dev:arm64 \
    libudev-dev:arm64 \
    libdrm-dev:arm64 \
    libglew-dev:arm64 \
    libopenal-dev:arm64 \
    libsndfile1-dev:arm64 \
    libfreeimage-dev:arm64 \
    libcairo2-dev:arm64 \
    libfreetype6-dev:arm64 \
    libpulse-dev:arm64 \
    libusb-1.0-0-dev:arm64 \
    libgtk2.0-dev:arm64 \
    libopencv-dev:arm64 \
    libassimp-dev:arm64 \
    librtaudio-dev:arm64 \
    gdb:arm64 \
    libglfw3-dev:arm64 \
    liburiparser-dev:arm64 \
    libpugixml-dev:arm64 \
    libgconf-2-4:arm64 \
    libgtk2.0-0:arm64 \
    libpoco-dev:arm64 \
    libxcursor-dev:arm64 \
    libxi-dev:arm64 \
    libxinerama-dev:arm64 \
    libgstreamer1.0-dev:arm64 \
    libgstreamer-plugins-base1.0-dev:arm64 \
    gstreamer1.0-libav:arm64 \
    gstreamer1.0-pulseaudio:arm64 \
    gstreamer1.0-x:arm64 \
    gstreamer1.0-plugins-bad:arm64 \
    gstreamer1.0-alsa:arm64 \
    gstreamer1.0-plugins-base:arm64 \
    gstreamer1.0-plugins-good:arm64

dpkg -L gcc-aarch64-linux-gnu

if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    find /usr/lib/x86_64-linux-gnu -name "libGL*"
fi
if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    find /usr/lib/x86_64-linux-gnu -name "libGL*"
fi

# Download the installer script
# CMAKE_VERSION=3.30.0
# wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh
# chmod +x cmake-${CMAKE_VERSION}-linux-x86_64.sh
# sudo ./cmake-${CMAKE_VERSION}-linux-x86_64.sh --skip-license --prefix=/usr/local
# export PATH="/usr/local/bin:$PATH"

# Verify the installation
cmake --version
