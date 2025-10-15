#!/usr/bin/env bash
set -e

LINUX_RELEASE=24.04.2

echo "=== Linux ARM64 cross setup ==="
lsb_release -a

sudo apt update -y
sudo apt install -y \
    debootstrap \
    qemu-user-static \
    binfmt-support \
    python3-minimal \
    python3-numpy \
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
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    python3-minimal \
    python3-numpy \
    mesa-utils mesa-common-dev libgl1-mesa-dev libegl1-mesa-dev

# if [[ "$(uname -m)" == "x86_64" ]]; then
#     wget https://ftp.gnu.org/gnu/gawk/gawk-5.3.1.tar.xz
#     tar --xz -xf gawk-5.3.1.tar.xz  # Explicitly tell tar to handle xz
#     cd gawk-5.3.1
#     ./configure
#     make
#     sudo make install
#     echo 'export LD_LIBRARY_PATH=/usr/local/lib/gawk:$LD_LIBRARY_PATH' >> ~/.zshrc
#     source ~/.zshrc
# fi

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
fi

UBUNTU_VERSION=$(lsb_release -cs) 
if [[ -z "$UBUNTU_VERSION" ]]; then
    echo "Error: Could not detect Ubuntu version. Ensure lsb-release is installed."
    exit 1
fi
if [[ "$(uname -m)" == "aarch64" ]]; then
    echo "Native aarch64 detected. No need to generate ARM64 /apt/sources. edits"
    SYSROOT="/"
else

echo "downloading aarch64 linux base"
IMAGE="ubuntu-base-$LINUX_RELEASE-base-arm64"
wget https://cdimage.ubuntu.com/ubuntu-base/releases/noble/release/${IMAGE}.tar.gz
mkdir arm64-rootfs
sudo tar -xpf ${IMAGE}.tar.gz -C arm64-rootfs
echo "===setup qemu==="
if [ ! -f "/arm64-rootfs/usr/bin/qemu-aarch64-static" ]; then
    echo "Copying qemu-aarch64-static into rootfs..."
    sudo cp /usr/bin/qemu-aarch64-static arm64-rootfs/usr/bin/
fi
sudo mount --bind /dev arm64-rootfs/dev
sudo mount --bind /proc arm64-rootfs/proc
sudo mount --bind /sys arm64-rootfs/sys
sudo chroot arm64-rootfs /bin/bash
SYSROOT="arm64-rootfs"

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


fi #end if arm64 / cross

if ! dpkg --print-foreign-architectures | grep -q "arm64"; then
    sudo dpkg --add-architecture arm64
fi
dpkg --print-architecture
dpkg --print-foreign-architectures
# Update package lists
echo "Updating APT package lists..."
sudo apt-get update

echo "Done! ARM64 and ARMHF architectures are ready."

ARCH_SUFFIX=":arm64"
if [[ "$(uname -m)" == "aarch64" ]]; then
    ARCH_SUFFIX=""
fi

echo "Installing ARM64 packages..."
sudo apt-get install -y \
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
    libwayland-dev$ARCH_SUFFIX \
    libxext-dev$ARCH_SUFFIX \
    libxcursor-dev$ARCH_SUFFIX \
    libxi-dev$ARCH_SUFFIX \
    ccache$ARCH_SUFFIX \
    libgles2-mesa-dev$ARCH_SUFFIX \
    libgl1-mesa-dev$ARCH_SUFFIX \
    libegl1-mesa-dev$ARCH_SUFFIX \
    libxkbcommon-dev$ARCH_SUFFIX

if [[ "$(uname -m)" != "aarch64" ]]; then  
    if [[ -d "arm64-rootfs/" ]]; then
        echo "Setting up Linux aarch64 toolchain inside rootfs..."
        sudo mkdir -p /usr/aarch64-linux-gnu
        sudo mkdir -p /arm64-rootfs/usr/aarch64-linux-gnu
        # Link the toolchain inside rootfs (Linux aarch64)
        sudo ln -s /arm64-rootfs/usr/bin/aarch64-linux-gnu-* /usr/aarch64-linux-gnu/
        sudo ln -s /arm64-rootfs/usr/lib /usr/lib/aarch64-linux-gnu/
        sudo ln -s /arm64-rootfs/usr/include /usr/aarch64-linux-gnu/include
        echo "Toolchain linked for Linux aarch64 at /usr/aarch64-linux-gnu/"
    else
        echo "Error: /arm64-rootfs/ does not exist. Ensure rootfs is extracted."
        exit 1
    fi
fi

sudo apt install -y \
    binfmt-support \
    python3-minimal \
    python3-numpy \
    git \
    cmake \
    pkgconf \
    build-essential \
    ninja-build \
    xz-utils \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu
    

if [ -d "/usr/lib/x86_64-linux-gnu" ]; then
    find /usr/lib/x86_64-linux-gnu -name "libGL*"

    lib_files=$(find /usr/lib/x86_64-linux-gnu -name "libGL*")

    if [ -z "$lib_files" ]; then
        echo "No libGL* files found in /usr/lib/x86_64-linux-gnu"
        exit 1
    fi
    echo -e "=== Running ldd on libGL* files ===="
    for file in $lib_files; do
        echo -e "File: $file"
        ldd "$file" || echo "Error: Could not run ldd on $file"
    done
fi
if [ -d "/usr/lib/aarch64-linux-gnu" ]; then
    find /usr/lib/aarch64-linux-gnu -name "libGL*"
    find /usr/lib/aarch64-linux-gnu -name "libwayland*"
else
    echo "Directory /usr/lib/aarch64-linux-gnu does not exist."
fi

if [ -d "/usr/aarch64-linux-gnu/bin/pkg-config" ]; then
    echo "Directory /usr/aarch64-linux-gnu/bin/pkg-config exists"
     find /usr/aarch64-linux-gnu/bin/pkg-config -name "pkg-config*"
else
    echo "Directory /usr/aarch64-linux-gnu/bin/pkg-config does not exist."
fi


dpkg -l | grep g++-aarch64-linux-gnu
dpkg -L libx11-dev:arm64 | grep libX11.so
dpkg -L libxext-dev:arm64 | grep libXext.so

export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig:$PKG_CONFIG_PATH
export PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig
export PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
pkg-config --list-all

