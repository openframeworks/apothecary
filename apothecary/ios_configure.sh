#!/usr/bin/env bash

#if [ "${TYPE}" == "tvos" ]; then
#    IOS_ARCHS="x86_64 arm64"
#elif [ "$TYPE" == "ios" ]; then
#    IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
#fi
TYPE=$1
IOS_ARCH=$2
declare -a HOSTS
declare -a SDKS
declare -a MIN_TYPES

if [ "${TYPE}" == "tvos" ]; then
    SIM=appletvsimulator
    OS=appletvos
    COS=AppleTvOS
    CSIM=AppleTvSimulator
    if [ "${IOS_ARCH}" == "x86_64" ]; then
        export HOST=x86_64-apple-darwin
        export SDK=$SIM
        export CSDK=$CSIM
        export ISSIM=TRUE
        export MIN_TYPE=-mtvos-simulator-version-min=
    elif [ "${IOS_ARCH}" == "arm64" ]; then
        export HOST=aarch64-apple-darwin
        export SDK=$OS
        export CSDK=$COS
        export ISSIM=FALSE
        export MIN_TYPE=-mtvos-version-min=
    else
        echo tvos arch $IOS_ARCH not supported by ios_configure.sh
        exit
    fi
elif [ "$TYPE" == "ios" ]; then
    SIM=iphonesimulator
    OS=iphoneos
    COS=iPhoneOS
    CSIM=iPhoneSimulator
    if [ "${IOS_ARCH}" == "i386" ]; then
        export HOST=i386-apple-darwin
        export SDK=$SIM
        export CSDK=$CSIM
        export ISSIM=TRUE
        export MIN_TYPE=-mios-simulator-version-min=
    elif [ "${IOS_ARCH}" == "x86_64" ]; then
        export HOST=x86_64-apple-darwin
        export SDK=$SIM
        export CSDK=$CSIM
        export ISSIM=TRUE
        export MIN_TYPE=-mios-simulator-version-min=
    elif [ "${IOS_ARCH}" == "armv7" ]; then
        export HOST=arm-apple-darwin
        export SDK=$OS
        export CSDK=$COS
        export ISSIM=FALSE
        export MIN_TYPE=-miphoneos-version-min=
    elif [ "${IOS_ARCH}" == "arm64" ]; then
        export HOST=aarch64-apple-darwin
        export SDK=$OS
        export CSDK=$COS
        export ISSIM=FALSE
        export MIN_TYPE=-miphoneos-version-min=
    else
        echo ios arch $IOS_ARCH not supported by ios_configure.sh
        exit
    fi
fi
export PLATFORM=$CSDK
#export CROSS_COMPILE=`xcode-select --print-path`/Toolchains/XcodeDefault.xctoolchain/usr/bin/
export CROSS_TOP=`xcode-select --print-path`/Platforms/${CSDK}.platform/Developer
export CROSS_SDK=${CSDK}.sdk

SDKVERSION=`xcrun -sdk ${OS} --show-sdk-version`
MIN_IOS_VERSION=$IOS_MIN_SDK_VER
BITCODE=""
if [[ "$TYPE" == "tvos" ]]; then
    MIN_IOS_VERSION=9.0
    BITCODE=-fembed-bitcode
fi

export CC="$(xcrun -find -sdk ${SDK} clang)"
export CXX="$(xcrun -find -sdk ${SDK} clang++)"
#export CPP="$(xcrun -find -sdk ${SDK} clang)"
export LIPO="$(xcrun -find -sdk ${SDK} lipo)"
export SYSROOT="$(xcrun -sdk ${SDK} --show-sdk-path)"
export CFLAGS="-arch ${IOS_ARCH}  -isysroot ${SYSROOT} -pipe -Os -gdwarf-2 $BITCODE -fPIC $MIN_TYPE$MIN_IOS_VERSION"
export LDFLAGS="-arch ${IOS_ARCH}  -isysroot ${SYSROOT}"
if [ "$SDK" = "iphonesimulator" ]; then
        export CPPFLAGS="-D__IPHONE_OS_VERSION_MIN_REQUIRED=${IPHONEOS_DEPLOYMENT_TARGET%%.*}0000"
fi
