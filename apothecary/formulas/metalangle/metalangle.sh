#!/usr/bin/env bash
#
# metalangle
# GLES -> Metal translation (MGLKit drop-in for EAGL/GLKit)
# https://github.com/kakashidinho/metalangle.git
#
# This is the MGLKit fork, NOT google/angle. The fork is frozen at
# ec92514 (2023-02-11) — that is the last tree that matches
# formulas/metalangle/metalangle/CMakeLists.txt + MGLKit.
# A chromium 2025+ SHA is a different formula (apothecary PR #533 `angle`).
# Swapping SOURCE_COMMIT onto google/angle will break this overlay.

FORMULA_TYPES=("osx" "ios" "tvos") # "catos" "xros" "watchos" @ TODO
FORMULA_DEPENDS=()

# define the version
VER=1.0
SOURCE_COMMIT=ec925142edeb1da3158fd8710ecc6dc2fb1f1f97
BUILD_ID=4
DEFINES="ANGLE_IS_64_BIT_CPU"
# frameworkFormula / xframeworkFormula emit this name instead of metalangle.xcframework
XCFRAMEWORK_NAME=MetalANGLE

# tools for git use
GIT_URL=https://github.com/kakashidinho/metalangle.git
GIT_ORIGIN=https://github.com/google/metalangle.git
GIT_TAG=v$VER

SCHEME=MetalANGLE
ARCHS=~/Library/Developer/Xcode/Archives

BUILD_CMAKE=true
BUILD_XCARCHIVE=false
BUILD_STATIC=false
FRAMEWORKS=""

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"

    if [ -d metalangle ]; then
        rm -rf metalangle
    fi
    git clone "${GIT_URL}" metalangle
    git -C metalangle checkout "$SOURCE_COMMIT"
    verify_git_commit metalangle "$SOURCE_COMMIT"
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echoVerbose "prepare metalangle @ $(pwd)"

    cp -R "${FORMULA_DIR}/metalangle/." ./

    echo "Fetch MetalANGLE third_party (glslang / spirv-cross / jsoncpp)"
    ./ios/xcode/fetchDependencies.sh

    # SPIRV-Cross f38cbeb (2020) calls std::terminate() without <exception>.
    # AppleClang 15+ / libc++ no longer pull that in transitively.
    local exception_hdr="third_party/spirv-cross/src/spirv_cross_containers.hpp"
    if [ -f "${exception_hdr}" ] && ! grep -q '#include <exception>' "${exception_hdr}"; then
        if [ -f "${FORMULA_DIR}/spirv-cross-exception.patch" ]; then
            patch -p1 --forward --reject-file=- < "${FORMULA_DIR}/spirv-cross-exception.patch" || true
        fi
        if ! grep -q '#include <exception>' "${exception_hdr}"; then
            sed -i.bak '/#include "spirv_cross_error_handling.hpp"/a\
#include <exception>
' "${exception_hdr}"
            rm -f "${exception_hdr}.bak"
        fi
    fi

    # commit_id.sh wants <angle_dir> <output>. Never hardcode a machine path.
    mkdir -p src/id
    if [ -x src/commit_id.sh ] || [ -f src/commit_id.sh ]; then
        bash src/commit_id.sh gen "$(pwd)" "$(pwd)/src/id/commit.h"
    else
        echoError "src/commit_id.sh missing after overlay"
        exit 1
    fi
}

function _metalangle_apple_frameworks() {
    # Static lib: these land on the archive's link line for consumers too.
    if [[ "$TYPE" == "osx" ]]; then
        echo "-framework QuartzCore -framework Metal -framework MetalKit -framework CoreFoundation -framework Foundation -framework AppKit -framework CoreGraphics -framework IOSurface -framework IOKit"
    elif [[ "$TYPE" == "tvos" ]]; then
        echo "-framework QuartzCore -framework Metal -framework MetalKit -framework CoreFoundation -framework Foundation -framework UIKit -framework CoreGraphics -framework OpenGLES -framework IOSurface"
    else
        echo "-framework QuartzCore -framework Metal -framework MetalKit -framework CoreFoundation -framework Foundation -framework UIKit -framework CoreGraphics -framework OpenGLES -framework IOSurface"
    fi
}

function _lipo_ios_simulator() {
    local dest="$1"
    local fatdir="${dest}/lib/ios/iphonesimulator"
    local combined="${dest}/lib/ios/SIMULATOR64COMBINED/MetalANGLE.a"
    local arm64="${dest}/lib/ios/SIMULATORARM64/MetalANGLE.a"
    local x64="${dest}/lib/ios/SIMULATOR64/MetalANGLE.a"
    mkdir -p "${fatdir}"
    if [[ -f "${combined}" ]]; then
        echo "iOS simulator MetalANGLE.a already combined (SIMULATOR64COMBINED)"
        cp -f "${combined}" "${fatdir}/MetalANGLE.a"
        lipo -info "${fatdir}/MetalANGLE.a"
    elif [[ -f "${arm64}" && -f "${x64}" ]]; then
        echo "lipo iOS simulator MetalANGLE.a (arm64 + x86_64)"
        lipo -create "${arm64}" "${x64}" -output "${fatdir}/MetalANGLE.a"
        lipo -info "${fatdir}/MetalANGLE.a"
    elif [[ -f "${arm64}" ]]; then
        echo "iOS simulator MetalANGLE.a: only arm64 slice present"
        cp -f "${arm64}" "${fatdir}/MetalANGLE.a"
    elif [[ -f "${x64}" ]]; then
        echo "iOS simulator MetalANGLE.a: only x86_64 slice present"
        cp -f "${x64}" "${fatdir}/MetalANGLE.a"
    fi
}

function _lipo_tvos_simulator() {
    local dest="$1"
    local fatdir="${dest}/lib/tvos/appletvsimulator"
    local arm64="${dest}/lib/tvos/SIMULATORARM64_TVOS/MetalANGLE.a"
    local x64="${dest}/lib/tvos/SIMULATOR_TVOS/MetalANGLE.a"
    mkdir -p "${fatdir}"
    if [[ -f "${arm64}" && -f "${x64}" ]]; then
        echo "lipo tvOS simulator MetalANGLE.a (arm64 + x86_64)"
        lipo -create "${arm64}" "${x64}" -output "${fatdir}/MetalANGLE.a"
        lipo -info "${fatdir}/MetalANGLE.a"
    elif [[ -f "${arm64}" ]]; then
        cp -f "${arm64}" "${fatdir}/MetalANGLE.a"
    elif [[ -f "${x64}" ]]; then
        cp -f "${x64}" "${fatdir}/MetalANGLE.a"
    fi
}

# executed inside the lib src dir
function build() {
    echo

    # `apo build` skips prepareFormula. Always re-apply overlay + third_party pins
    # so a stale SPIRV-Cross checkout cannot silently break the Metal backend.
    prepare

    LIBS_ROOT=$(realpath $LIBS_DIR)
    CORE_DIR=$(pwd)

    DEFS="
		    -DCMAKE_C_STANDARD=${C_STANDARD} \
		    -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		    -DCMAKE_CXX_STANDARD_REQUIRED=ON \
		    -DCMAKE_CXX_EXTENSIONS=OFF \
		    -DCMAKE_PREFIX_PATH=${LIBS_ROOT} \
		    -DBUILD_SHARED_LIBS=OFF"

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        XC_PROJECT_PATH="./ios/xcode/OpenGLES.xcodeproj"

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"

        if [[ $BUILD_CMAKE == true ]]; then

            rm -f CMakeCache.txt *.a *.o
            if [[ "$TYPE" =~ ^(catos)$ ]]; then
                X_DEFS="-DSUPPORTS_MACCATALYST=YES "
            else
                X_DEFS=""
            fi

            FRAMEWORKS="$(_metalangle_apple_frameworks)"
            DEFINES="${DEFINES} ${FRAMEWORKS}"
            cmake .. ${DEFS} ${X_DEFS} \
                -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
                -DPLATFORM=$PLATFORM \
                -DCMAKE_INSTALL_PREFIX=Release \
                -DCMAKE_BUILD_TYPE=Release \
                -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
                -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
                -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
                -DCMAKE_EXE_LINKER_FLAGS="${FRAMEWORKS}" \
                -DENABLE_BITCODE=OFF \
                -DENABLE_ARC=ON \
                -DENABLE_VISIBILITY=OFF \
                -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
                -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
                -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22
            cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        fi

        ARCHS=Release
        mkdir -p $ARCHS

        XC_PROJECT_PATH="../ios/xcode/OpenGLES.xcodeproj"
        XC_PROJECT_PATH=$(realpath $XC_PROJECT_PATH)

        SCHEME=MetalANGLE
        SCHEME_MAC=MetalANGLE_mac
        SCHEME_TV=MetalANGLE_tvos
        SCHEME_VISION=MetalANGLE_xros

        XBUILD_DIR=$(pwd)

        if [[ $BUILD_XCARCHIVE == true ]]; then

            if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
                # Ensure we're using the correct Xcode project path
                if [[ -d "$XC_PROJECT_PATH" ]]; then
                    # For each platform type, run the xcodebuild command with XC_PROJECT_PATH
                    if [[ "$TYPE" =~ ^(xros)$ ]]; then
                        echo "*** Creating archive for visionOS ***"
                        xcodebuild archive -scheme $SCHEME_VISION -archivePath $ARCHS/MetalANGLE.xcarchive -sdk xros SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                        echo "*** Creating archive for visionOS Simulator ***"
                        xcodebuild archive -scheme $SCHEME_VISION -archivePath $ARCHS/MetalANGLE.xcarchive -sdk xrsimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                    elif [[ "$TYPE" =~ ^(tvos)$ ]]; then
                        echo "*** Creating archive for tvOS ***"
                        xcodebuild archive -scheme $SCHEME_TV -archivePath $ARCHS/MetalANGLE.xcarchive -sdk appletvos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                        echo "*** Creating archive for tvOS Simulator ***"
                        xcodebuild archive -scheme $SCHEME_TV -archivePath $ARCHS/MetalANGLE.xcarchive -sdk appletvsimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                    elif [[ "$TYPE" =~ ^(ios)$ ]]; then
                        echo "*** Creating archive for iOS ***"
                        xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/MetalANGLE.xcarchive -sdk iphoneos SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                        echo "*** Creating archive for iOS Simulator ***"
                        xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/MetalANGLE.xcarchive -sdk iphonesimulator SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                    elif [[ "$TYPE" =~ ^(catos)$ ]]; then
                        echo "*** Creating archive for Mac Catalyst ***"
                        xcodebuild archive -scheme $SCHEME -archivePath $ARCHS/MetalANGLE.xcarchive -destination "generic/platform=macOS,variant=Mac Catalyst" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES -project "${XC_PROJECT_PATH}"
                    elif [[ "$TYPE" =~ ^(osx)$ ]]; then
                        echo "*** Creating archive for macOS ***"
                        xcodebuild archive -scheme $SCHEME_MAC -archivePath $ARCHS/MetalANGLE.xcarchive -destination "generic/platform=macOS,name=Any Mac" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}"
                    fi
                else
                    echo "Error: Xcode project not found at $XC_PROJECT_PATH"
                    exit 1
                fi
            fi

        fi

        if [[ $BUILD_STATIC == true ]]; then

            if [[ "$TYPE" =~ ^(xros)$ ]]; then
                # visionOS static library build
                echo "*** Building static library for visionOS ***"
                xcodebuild clean build -scheme $SCHEME_VISION -configuration Release -sdk xros BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"
                echo "*** Building static library for visionOS Simulator ***"
                xcodebuild clean build -scheme $SCHEME_VISION -configuration Release -sdk xrsimulator BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"

            elif [[ "$TYPE" =~ ^(tvos)$ ]]; then
                # tvOS static library build
                echo "*** Building static library for tvOS ***"
                xcodebuild clean build -scheme $SCHEME_TV -configuration Release -sdk appletvos BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"
                echo "*** Building static library for tvOS Simulator ***"
                xcodebuild clean build -scheme $SCHEME_TV -configuration Release -sdk appletvsimulator BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"

            elif [[ "$TYPE" =~ ^(ios)$ ]]; then
                # iOS static library build
                echo "*** Building static library for iOS ***"
                xcodebuild clean build -scheme $SCHEME -configuration Release -sdk iphoneos BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"
                echo "*** Building static library for iOS Simulator ***"
                xcodebuild clean build -scheme $SCHEME -configuration Release -sdk iphonesimulator BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"

            elif [[ "$TYPE" =~ ^(catos)$ ]]; then
                # Mac Catalyst static library build
                echo "*** Building static library for Mac Catalyst ***"
                xcodebuild clean build -scheme $SCHEME -configuration Release -destination "generic/platform=macOS,variant=Mac Catalyst" BUILD_LIBRARIES_FOR_DISTRIBUTION=YES SUPPORTS_MACCATALYST=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"

            elif [[ "$TYPE" =~ ^(osx)$ ]]; then
                # macOS static library build
                echo "*** Building static library for macOS ***"
                xcodebuild clean build -scheme $SCHEME_MAC -configuration Release -destination "generic/platform=macOS,name=Any Mac" BUILD_LIBRARIES_FOR_DISTRIBUTION=YES -project "${XC_PROJECT_PATH}" -derivedDataPath "$XBUILD_DIR"
            fi

        fi

    fi

    echo "build complete"

    cd ${CORE_DIR}

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    echo "copy metalangle -> $1"
    mkdir -p "$1"
    if [ -d "$1/include" ]; then
        rm -rf "$1/include"
    fi
    mkdir -p "$1/include"

    # Public GLES / EGL / KHR headers from the install prefix when present,
    # otherwise the source include/ tree.
    if [ -d "build_${TYPE}_${PLATFORM}/Release/include" ]; then
        cp -R "build_${TYPE}_${PLATFORM}/Release/include/." "$1/include/"
    elif [ -d include ]; then
        cp -R include/. "$1/include/"
    fi

    # MGLKit drop-in (MGLContext / MGLKView / MGLLayer)
    if [ -d ios/xcode/MGLKit ]; then
        mkdir -p "$1/include/MGLKit"
        find ios/xcode/MGLKit -maxdepth 1 \( -name '*.h' -o -name '*.hpp' \) -exec cp -v {} "$1/include/MGLKit/" \;
    fi

    if [ -f src/id/commit.h ]; then
        mkdir -p "$1/include/id"
        cp -v src/id/commit.h "$1/include/id/commit.h"
    fi

    . "$SECURE_SCRIPT"
    mkdir -p "$1/lib/$TYPE"

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        mkdir -p "$1/lib/$TYPE/$PLATFORM/"
        if [[ $BUILD_STATIC == true ]] || [[ $BUILD_CMAKE == true ]]; then
            local built=""
            local cand
            for cand in \
                "build_${TYPE}_${PLATFORM}/Release/lib/libMetalANGLE.a" \
                "build_${TYPE}_${PLATFORM}/Release/lib/libmetalangle.a" \
                "build_${TYPE}_${PLATFORM}/Release/lib/MetalANGLE.a" \
                "build_${TYPE}_${PLATFORM}/Release/lib/metalangle.a"; do
                if [ -f "$cand" ]; then
                    built="$cand"
                    break
                fi
            done
            if [ -z "$built" ]; then
                echoError "metalangle: no MetalANGLE archive under build_${TYPE}_${PLATFORM}/Release/lib"
                ls -la "build_${TYPE}_${PLATFORM}/Release/lib" 2>/dev/null || true
                exit 1
            fi
            # One archive named MetalANGLE.a (secure this path — not a lowercase alias).
            cp -v "$built" "$1/lib/$TYPE/$PLATFORM/MetalANGLE.a"
            secure "$1/lib/$TYPE/$PLATFORM/MetalANGLE.a" "MetalANGLE.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        fi
        local fw
        for fw in \
            "build_${TYPE}_${PLATFORM}/Release/MetalANGLE.framework" \
            "build_${TYPE}_${PLATFORM}/Release/lib/MetalANGLE.framework"; do
            if [ -d "$fw" ]; then
                rm -rf "$1/lib/$TYPE/$PLATFORM/MetalANGLE.framework"
                cp -R "$fw" "$1/lib/$TYPE/$PLATFORM/MetalANGLE.framework"
            fi
        done
        if [[ $BUILD_XCARCHIVE == true ]]; then
            if [ -d "build_${TYPE}_${PLATFORM}/Release/MetalANGLE.xcarchive" ]; then
                cp -R "build_${TYPE}_${PLATFORM}/Release/MetalANGLE.xcarchive" "$1/lib/$TYPE/$PLATFORM/MetalANGLE.xcarchive"
            fi
        fi
        if [[ "$TYPE" == "ios" ]]; then
            _lipo_ios_simulator "$1"
        elif [[ "$TYPE" == "tvos" ]]; then
            _lipo_tvos_simulator "$1"
        fi
    fi

    if [ -d "$1/license" ]; then
        rm -rf "$1/license"
    fi
    mkdir -p "$1/license"
    if [ -f LICENSE ]; then
        cp -v LICENSE "$1/license/"
    fi
}

# executed inside the lib src dir
function clean() {
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        rm -rf "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "metalangle" ${ARCH} ${VER} "$LIBS_DIR_REAL/metalangle/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        TARGET_DIR="$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM"
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        else
            echoInfo "Folder does not exist: $TARGET_DIR"
        fi
        echo 0
    fi
}
