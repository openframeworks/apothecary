#!/bin/bash
set -e
echo "=== Linux ARM64 cross setup ==="
lsb_release -a

sudo apt update -y
sudo apt install -y \
    git \
    cmake \
    gawk \
    pkgconf \
    build-essential \
    ninja-build \
    automake \
    autoconf \
    flex \
    xz-utils \
    crossbuild-essential-armhf \
    crossbuild-essential-arm64 \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    debootstrap \
    qemu-user-static \
    binfmt-support


sudo apt install -y \
    python3-minimal \
    python3-numpy

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Ubuntu version detection
UBUNTU_VERSION=$(lsb_release -cs)  # e.g., "lunar" for Ubuntu 23.04

# Check for valid Ubuntu version
if [[ -z "$UBUNTU_VERSION" ]]; then
    echo "Error: Could not detect Ubuntu version. Ensure lsb-release is installed."
    exit 1
fi
if [[ "$(uname -m)" == "aarch64" ]]; then
    echo "Native aarch64 detected. No need to generate ARM64 /apt/sources. edits"
else

sudo mount --bind /dev rpi-arm64-rootfs/dev
sudo mount --bind /proc rpi-arm64-rootfs/proc
sudo mount --bind /sys rpi-arm64-rootfs/sys

sudo chroot rpi-arm64-rootfs /bin/bash


# Define output file path
OUTPUT_FILE="/etc/apt/sources.list.d/raspberrypi-arm64.sources"
echo "Creating sources file for Raspberry Pi (ARM64) at $OUTPUT_FILE"
cat <<EOF > $OUTPUT_FILE
Types: deb
URIs: http://deb.debian.org/debian
Suites: bookworm bookworm-updates bookworm-backports bookworm-security
Components: main contrib non-free-firmware
Architectures: arm64
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://archive.raspberrypi.com/debian
Suites: bookworm
Components: main
Architectures: arm64
Signed-By: /usr/share/keyrings/raspberrypi-archive-keyring.gpg
EOF

echo "Generated Raspberry Pi sources file at $OUTPUT_FILE"


SOURCE_FILE="/etc/apt/sources.list.d/ubuntu.sources"
awk '
/^Types: deb/ {
    print $0
    getline nextLine
    if (nextLine !~ /^Architectures:/) {
        print "Architectures: amd64"
    }
    print nextLine
    next
}
{ print $0 }
' "$SOURCE_FILE" > "${SOURCE_FILE}.tmp"
mv "${SOURCE_FILE}.tmp" "$SOURCE_FILE"
echo "'Architectures: amd64' added where missing after 'Types: deb' in $SOURCE_FILE."

fi

if ! dpkg --print-foreign-architectures | grep -q "arm64"; then
    sudo dpkg --add-architecture arm64
fi
dpkg --print-architecture
dpkg --print-foreign-architectures

# Update package lists
echo "Updating APT package lists..."
sudo apt-get update
echo "Done! ARM64 and ARMHF architectures are ready."

echo "Installing ARM64 packages..."
ARCH_SUFFIX=":arm64"
if [[ "$(uname -m)" == "aarch64" ]]; then
    ARCH_SUFFIX=""
fi

if [ -d "/raspbian/" ]; then
    sudo mkdir -p /usr/aarch64-linux-gnu
    sudo ln -s /raspbian/toolchain/bin/aarch64-linux-gnu-* /usr/aarch64-linux-gnu/
    sudo ln -s /raspbian/toolchain/lib /usr/aarch64-linux-gnu/lib
    sudo ln -s /raspbian/toolchain/include /usr/aarch64-linux-gnu/include
else
    echo "Error: /raspbian/ folder not found. Please check your installation."
    exit 1
fi

echo "Installing ARM64 packages..."
sudo apt-get install -y --no-install-recommends \
    aptitude$ARCH_SUFFIX \
    gfortran$ARCH_SUFFIX \
    texinfo$ARCH_SUFFIX \
    bison$ARCH_SUFFIX \
    libncurses-dev$ARCH_SUFFIX \
    unzip$ARCH_SUFFIX \
    pkg-config$ARCH_SUFFIX \
    flex$ARCH_SUFFIX \
    openssl$ARCH_SUFFIX \
    pigz$ARCH_SUFFIX \
    autoconf$ARCH_SUFFIX \
    automake$ARCH_SUFFIX \
    figlet$ARCH_SUFFIX \
    gperf$ARCH_SUFFIX \
    libgl1-mesa-dev$ARCH_SUFFIX \
    libglu1-mesa-dev$ARCH_SUFFIX \
    freeglut3-dev$ARCH_SUFFIX \
    libxrandr-dev$ARCH_SUFFIX \
    libxinerama-dev$ARCH_SUFFIX \
    libx11-dev$ARCH_SUFFIX \
    libxext-dev$ARCH_SUFFIX \
    libxcursor-dev$ARCH_SUFFIX \
    libxi-dev$ARCH_SUFFIX \
    ccache$ARCH_SUFFIX \
    libgles2-mesa-dev$ARCH_SUFFIX


if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    find /usr/lib/x86_64-linux-gnu -name "libGL*"

    lib_files=$(find /usr/lib/x86_64-linux-gnu -name "libGL*")

    if [ -z "$lib_files" ]; then
        echo "No libGL* files found in /usr/lib/x86_64-linux-gnu"
        exit 1
    fi
    echo -e "\n\033[1;32m==== Running ldd on libGL* files ====\033[0m"
    for file in $lib_files; do
        echo -e "\n\033[1;34mFile: $file\033[0m"
        ldd "$file" || echo "Error: Could not run ldd on $file"
    done
fi
if [ -d "/usr/lib/aarch64-linux-gnu" ]; then
    find /usr/lib/aarch64-linux-gnu -name "libGL*"
else
    echo "Directory /usr/lib/aarch64-linux-gnu does not exist."
fi

PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig \
    PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu \
    PKG_CONFIG_SYSROOT_DIR=/ \
      pkg-config --list-all
