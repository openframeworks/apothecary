#!/bin/bash
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR
APOTHECARY_LEVEL="$(cd "$SCRIPT_DIR/../.." && pwd)"

set -e

echo "=== Linux ARM64 cross setup ==="
lsb_release -a

sudo apt update -y
sudo apt install -y \
    git \
    cmake \
    pkgconf \
    build-essential \
    ninja-build \
    gawk \
    automake \
    autoconf \
    flex \
    crossbuild-essential-armhf \
    crossbuild-essential-arm64

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
# Define output file path
OUTPUT_FILE="/etc/apt/sources.list.d/arm64.sources"
echo "making sources file arm64"

# Generate the .sources content
cat <<EOF > $OUTPUT_FILE
Types: deb
URIs: http://ports.ubuntu.com/ubuntu-ports/
Suites: $UBUNTU_VERSION $UBUNTU_VERSION-updates $UBUNTU_VERSION-backports $UBUNTU_VERSION-security
Components: main restricted universe multiverse
Architectures: arm64 armhf
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# Output the result
echo "Generated ARM64 .sources file at $OUTPUT_FILE"


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
sudo dpkg --add-architecture arm64
sudo dpkg --add-architecture amd64
dpkg --print-architecture
dpkg --print-foreign-architectures

# Update package lists
echo "Updating APT package lists..."
sudo apt-get update
echo "Done! ARM64 and ARMHF architectures are ready."

echo "Installing ARM64 packages..."
apt-get install -y \
    aptitude:arm64 \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    gfortran:arm64 \
    texinfo:arm64 \
    bison:arm64 \
    libncurses-dev:arm64 \
    unzip:arm64 \
    pkg-config:arm64 \
    flex:arm64 \
    openssl:arm64 \
    pigz:arm64 \
    autoconf:arm64 \
    automake:arm64 \
    figlet:arm64 \
    xz-utils:arm64 \
    gperf:arm64 \
    libgl1-mesa-dev:arm64 \
    libglu1-mesa-dev:arm64 \
    freeglut3-dev:arm64 \
    libxrandr-dev:arm64 \
    libxinerama-dev:arm64 \
    libx11-dev:arm64 \
    libxext-dev:arm64 \
    libxcursor-dev:arm64 \
    libxi-dev:arm64 \
    ccache:arm64 \
    binutils-aarch64-linux-gnu:arm64 \
    libgles2-mesa-dev:arm64

# apt-get install -y gawk:arm64 --no-remove
if [[ "$(uname -m)" == "x86_64" ]]; then
    # issues with apt packages install manually
    wget http://ftp.us.debian.org/debian/pool/main/g/gawk/gawk_5.2.1-2+b2_arm64.deb
    sudo dpkg -i --force-architecture --force-depends gawk_5.2.1-2+b2_arm64.deb
fi


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
