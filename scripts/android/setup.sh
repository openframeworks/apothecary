#!/usr/bin/env bash
set -e
APOTHECARY_PATH=$(
    cd $(dirname "$0")
    pwd -P
)/../../apothecary

# Check for predefined Android environment variables

if [ -n "$NDK" ]; then
    NDK_VERSION=${NDK}
    echo "Using ANDROID_NDK_VERSION: $NDK"
fi

if [ -n "$SDK" ]; then
    SDK_VERSION=${SDK}
    echo "Using ANDROID_SDK: $SDK"
fi

if [ -n "$ANDROID_NDK_ROOT" ]; then
    NDK_ROOT="$ANDROID_NDK_ROOT"
    echo "Using ANDROID_NDK_ROOT: $NDK_ROOT"
elif [ -n "$ANDROID_NDK" ]; then
    NDK_ROOT="$ANDROID_NDK"
    echo "Using ANDROID_NDK: $NDK_ROOT"
elif [ -n "$ANDROID_NDK_HOME" ]; then
    NDK_ROOT="$ANDROID_NDK_HOME"
    echo "Using ANDROID_NDK_HOME: $NDK_ROOT"
elif [ -n "$ANDROID_NDK_LATEST_HOME" ]; then
    NDK_ROOT="$ANDROID_NDK_LATEST_HOME"
    echo "Using ANDROID_NDK_LATEST_HOME: $NDK_ROOT"
else
    # Fallback to default NDK setup if no environment variables are found
    NDK_VERSION="r24"
    NDK_ROOT="$(realpath ~/)/android-ndk-${NDK_VERSION}/"
    echo "No Android NDK environment variables found. Falling back to default: $NDK_ROOT"

    # Check if the NDK directory exists and is non-empty
    if [ -d "${NDK_ROOT}" ] && [ "$(ls -A ${NDK_ROOT})" ]; then
        echo "Using cached NDK at $NDK_ROOT"
        ls -A "${NDK_ROOT}"
    else
        cd ~/
        echo "Downloading NDK $NDK_VERSION"
        wget -q --no-check-certificate https://dl.google.com/android/repository/android-ndk-${NDK_VERSION}-linux.zip
        echo "Uncompressing NDK"
        unzip android-ndk-${NDK_VERSION}-linux.zip >/dev/null 2>&1
        rm android-ndk-${NDK_VERSION}-linux.zip
        echo "NDK installed at $NDK_ROOT"
        cd -
    fi
    echo "NDK_ROOT=${NDK_ROOT};" >"${APOTHECARY_PATH}/paths.make"
fi
