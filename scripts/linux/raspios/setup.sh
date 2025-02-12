#!/bin/bash
set -e
set -o pipefail

trap "echo ' ^ Received error ^' && exit 1" ERR

RPI_TARGET="${RPI_TARGET:-auto}"
GCC_VERSION="${GCC_VERSION:-gcc14}"
INSTALL_DIR="$HOME/opt"

ARCH=$(uname -m)
if grep -q "Raspbian" /etc/os-release 2>/dev/null; then
    NATIVE="true"
    echo "Detected Raspberry Pi OS (Raspbian). Determining native RPI_TARGET..."
    
    RPI_MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")

    # Check for Raspberry Pi Pico (RP2040) by scanning USB devices
    if lsusb | grep -q "Raspberry Pi RP2"; then
        echo "Detected Raspberry Pi Pico (RP2040)"
        RPI_TARGET="arm-pico-eabi"
    elif lsusb | grep -q "RP2350"; then
        echo "Detected Raspberry Pi Pico 2 (RP2350)"
        RPI_TARGET="arm-pico2-eabi"
    else
        case "$ARCH" in
            aarch64)
                # 64-bit OS
                if echo "$RPI_MODEL" | grep -q "Raspberry Pi 4\|Raspberry Pi 5"; then
                    RPI_TARGET="aarch64-rpi3-linux-gnu"
                elif echo "$RPI_MODEL" | grep -q "Raspberry Pi 3"; then
                    RPI_TARGET="aarch64-rpi3-linux-gnu"
                else
                    RPI_TARGET="aarch64-rpi3-linux-gnu"  # Default for unknown 64-bit systems
                fi
                ;;

            armv7l)
                # 32-bit ARMv7 (Pi 2 v1.2, Pi 3 in 32-bit mode)
                RPI_TARGET="armv8-rpi3-linux-gnueabihf"
                ;;

            armv6l)
                # 32-bit ARMv6 (Pi Zero, Pi 1)
                RPI_TARGET="armv6-rpi-linux-gnueabihf"
                ;;

            *)
                echo "Unknown architecture: $ARCH. Defaulting to armv6-rpi-linux-gnueabihf."
                RPI_TARGET="armv6-rpi-linux-gnueabihf"
                ;;
        esac
    fi
    echo "Auto-detected RPI_TARGET: $RPI_TARGET"
else
    NATIVE="false"
fi

case "$RPI_TARGET" in
    aarch64-rpi3-linux-gnu)
        if [[ "$ARCH" == "x86_64" ]] || [[ "$NATIVE" == "true" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-${GCC_VERSION}.tar.xz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-aarch64-rpi3-linux-gnu-${GCC_VERSION}.tar.xz"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        TOOLCHAIN_NAME="x-tools-aarch64-rpi3-linux-gnu"
        ;;
    
    armv8-rpi3-linux-gnueabihf)
        if [[ "$ARCH" == "x86_64" ]] || [[ "$NATIVE" == "true" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-armv8-rpi3-linux-gnueabihf-${GCC_VERSION}.tar.xz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-armv8-rpi3-linux-gnueabihf-${GCC_VERSION}.tar.xz"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        TOOLCHAIN_NAME="x-tools-armv8-rpi3-linux-gnueabihf"
        ;;

    armv6-rpi-linux-gnueabihf)
        if [[ "$ARCH" == "x86_64" ]] || [[ "$NATIVE" == "true" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-armv6-rpi-linux-gnueabihf-${GCC_VERSION}.tar.xz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-armv6-rpi-linux-gnueabihf-${GCC_VERSION}.tar.xz"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        TOOLCHAIN_NAME="x-tools-armv6-rpi-linux-gnueabihf"
        ;;

    arm-pico-eabi)
        if [[ "$ARCH" == "x86_64" ]] || [[ "$NATIVE" == "true" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-arm-pico-eabi-${GCC_VERSION}.tar.xz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-arm-pico-eabi-${GCC_VERSION}.tar.xz"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        TOOLCHAIN_NAME="x-tools-arm-pico-eabi"
        ;;

    arm-pico2-eabi)
        if [[ "$ARCH" == "x86_64" ]] || [[ "$NATIVE" == "true" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-arm-pico2-eabi-${GCC_VERSION}.tar.xz"
        elif [[ "$ARCH" == "aarch64" ]]; then
            TOOLCHAIN_URL="https://github.com/tttapa/docker-arm-cross-toolchain/releases/latest/download/x-tools-aarch64-rpi3-linux-gnu-arm-pico2-eabi-${GCC_VERSION}.tar.xz"
        else
            echo "Unsupported architecture: $ARCH"
            exit 1
        fi
        TOOLCHAIN_NAME="x-tools-arm-pico2-eabi"
        ;;
    
    *)
        echo "Unknown RPI_TARGET: $RPI_TARGET"
        exit 1
        ;;
esac

# Download and extract toolchain
echo "Downloading toolchain: $TOOLCHAIN_NAME"
mkdir -p "$INSTALL_DIR"
wget -q "$TOOLCHAIN_URL" -O "$INSTALL_DIR/${TOOLCHAIN_NAME}.tar.xz"

echo "Extracting toolchain..."
tar -xf "$INSTALL_DIR/${TOOLCHAIN_NAME}.tar.xz" -C "$INSTALL_DIR"
rm "$INSTALL_DIR/${TOOLCHAIN_NAME}.tar.xz"

# Set up environment variables
TOOLCHAIN_PATH="$INSTALL_DIR/$TOOLCHAIN_NAME/bin"
echo "Setting up environment variables..."
export PATH="$TOOLCHAIN_PATH:$PATH"

# Add to ~/.profile for persistence
echo "export PATH=\"$TOOLCHAIN_PATH:\$PATH\"" >> ~/.profile
source ~/.profile

# Verify installation
echo "Verifying toolchain setup..."
${RPI_TARGET}-gcc --version || echo "Error: ${RPI_TARGET}-gcc not found in PATH"

echo "=== Setup complete ==="
