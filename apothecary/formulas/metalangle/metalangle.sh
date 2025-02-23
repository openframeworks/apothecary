#!/usr/bin/env bash
#
# metalangle
# https://github.com/kakashidinho/metalangle.git

FORMULA_TYPES=("osx" "ios" "tvos") # "catos" "xros" "watchos" @ TODO
FORMULA_DEPENDS=()

# define the version
VER=1.0
BUILD_ID=2
DEFINES=""

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
DEFINES="ANGLE_IS_64_BIT_CPU"

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    git clone ${GIT_URL}
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo

    echo "Fetch Subdependancies"
    ./ios/xcode/fetchDependencies.sh

    cp -r $FORMULA_DIR/metalangle/ ./

    mkdir -p "src/id"
    ./src/commit_id.sh gen /Users/one/SOURCE/apothecary/apothecary/build/metalangle/src ./src/id/commit.h

    # cp -r $FORMULA_DIR/metalangle/CMakeLists.txt metalangle/CMakeLists.txt
}

# executed inside the lib src dir
function build() {
    echo

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

        # rm -f build_${TYPE}_${PLATFORM}

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
            if [[ "$TYPE" =~ ^(ios)$ ]]; then
                X_LINKER=" -framework OpenGLES -framework IOSurface "
            else
                X_LINKER=" -framework OpenGLES -framework IOSurface"
            fi

            FRAMEWORKS="-framework QuartzCore -framework Metal -framework CoreFoundation -framework Foundation -framework UIKIT -framework CoreGraphics ${X_LINKER}"
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
    echo "copy"
    # # headers
    mkdir -p $1
    if [ -d "$1/include" ]; then
        rm -rf $1/include/*
    fi
    mkdir -p $1/include
    cp -Rv include/* $1/include

    echo "Copying src headers..."
    mkdir -p "$1/include/src"
    cp -Rv src/* "$1/include/src"

    if [ -d "$1/include/src/tests" ]; then
        echo "Removing existing folder: $1/include/src/tests"
        rm -rf "$1/include/src/tests"
    fi

    echo "Copying third-party glslang headers..."
    mkdir -p "$1/include/third_party/glslang/src"
    cp -Rv third_party/glslang/src/* "$1/include/third_party/glslang/src/"

    # echo "Copying third-party glslang headers..."
    # mkdir -p "$1/include/third_party/glslang/src"
    # cp -Rv third_party/glslang/src/* "$1/include/third_party/glslang/src/"

    if [ -d "$1/include/third_party/glslang/src/Test" ]; then
        echo "Removing existing folder: $1/include/third_party/glslang/src/Test"
        rm -rf "$1/include/third_party/glslang/src/Test"
    fi

    echo "Copying third-party spirv-cross headers..."
    mkdir -p "$1/include/third_party/spirv-cross/src"
    cp -Rv third_party/spirv-cross/src/* "$1/include/third_party/spirv-cross/src/"

    # echo "Copying third-party jsoncpp overrides..."
    # mkdir -p "$1/include/third_party/jsoncpp/overrides/include"
    # cp -Rv third_party/jsoncpp/overrides/include/* "$1/include/third_party/jsoncpp/overrides/include/"

    echo "Copying third-party jsoncpp source..."
    mkdir -p "$1/include/third_party/jsoncpp/source/include"
    cp -Rv third_party/jsoncpp/source/include/* "$1/include/third_party/jsoncpp/source/include/"

    # find "$1/include" -type f > "$1/include/files.txt"
    EXTENSIONS=(
        ".asm" ".jpg" ".gif" ".sh" ".py" ".gn" ".gni" ".yml" ".cfg"
        ".frag" ".comp" ".vert" ".tese" ".tesc" ".geom" ".hlsl" ".spv"
        ".vk" ".patch" ".rchit" ".multi" ".template" ".m4" ".inc" ".DS_Store" ".clang-format"
    )

    # Iterate through each extension and remove matching files
    for ext in "${EXTENSIONS[@]}"; do
        find "$1/include" -type f -name "*$ext" -exec rm -v {} \;
    done

    echo "Removing not needed shaders folder: 1/include/src/libANGLE/renderer/d3d"
    if [ -d "$1/include/src/libANGLE/renderer/d3d/d3d9/shaders" ]; then
        rm -rf "$1/include/src/libANGLE/renderer/d3d/d3d9/shaders"
    fi
    if [ -d "$1/include/src/libANGLE/renderer/d3d/d3d11/shaders" ]; then
        rm -rf "$1/include/src/libANGLE/renderer/d3d/d3d11/shaders"
    fi

    # find "$1/include" -type f > "$1/include/filesafter.txt"

    . "$SECURE_SCRIPT"
    mkdir -p $1/lib/$TYPE

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        cp -v -r build_${TYPE}_${PLATFORM}/Release/include/* $1/include
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        if [[ $BUILD_STATIC == true ]] || [[ $BUILD_CMAKE == true ]]; then
            cp -Rv build_${TYPE}_${PLATFORM}/Release/lib/libmetalangle.a $1/lib/$TYPE/$PLATFORM/MetalANGLE.a
            secure "$1/lib/$TYPE/$PLATFORM/metalangle.a" "metalangle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        fi
        if [[ $BUILD_XCARCHIVE == true ]]; then
            cp -Rv build_${TYPE}_${PLATFORM}/Release/MetalANGLE.xcarchive $1/lib/$TYPE/$PLATFORM/MetalANGLE.xcarchive
        fi
    fi

    # copy license files
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        rm -f build_${TYPE}_${PLATFORM}
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
        # Check if the folder exists
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        else
            echoInfo "Folder does not exist: $TARGET_DIR"
        fi
        echo 0
    fi
}
