#!/bin/bash

# Apothecary ROOT dir relative
ROOT=$(cd "$(dirname "$0")"; pwd -P)/../../
SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
APOTHECARY_PATH=$ROOT/apothecary

# Set OF_ROOT directory
if [ -z "${OF_ROOT+x}" ]; then
    export OF_ROOT=$(cd "$(dirname "$0")"; pwd -P)/../../../../
fi

# openFrameworks libs directory
OF_LIBS=$OF_ROOT/libs

# control 
if [ -z "${BUILD_LIBRARIES+x}" ]; then
    BUILD_LIBRARIES=1
fi

if [ -z "${MOVE_LIBRARIES+x}" ]; then
    MOVE_LIBRARIES=1
fi

if [ -z "${PLATFORM+x}" ]; then
    PLATFORM=vs
fi

if [ -z "${ARCH+x}" ]; then
    ARCH=arm64
fi

build_libraries() {
    for BUNDLE_NO in {1..4}
    do
        echo "Building $PLATFORM $ARCH bundle $BUNDLE_NO"

        # Set OUTPUT_FOLDER for the build
        export OUTPUT_FOLDER="$ROOT/out"
        
        ${SCRIPT_DIR}/./build_${PLATFORM}_${ARCH}.sh ${BUNDLE_NO}

        # Check for successful completion
        if [ $? -ne 0 ]; then
            echo "Error building bundle $BUNDLE_NO"
            exit 1
        fi
    done
}

# move built libraries to openFrameworks libs directory
move_libraries() {

    if ! command -v rsync &> /dev/null; then
        echo "Using cp to move libraries..."
        cp -a "$OUTPUT_FOLDER/." "$OF_LIBS/"
    else
        echo "Using rsync to move libraries..."
        rsync -a "$OUTPUT_FOLDER/" "$OF_LIBS/"
    fi

    echo "Libraries moved to openFrameworks libs directory."
}

# sort libraries from openFrameworks libs to addons directories where applicable
sort_libraries() {
    if [ "$PLATFORM" == "osx" ]; then
        addonslibs=("opencv" "ippicv" "libusb" "assimp" "libxml2" "svgtiny" "poco" "openssl")
        addons=("ofxOpenCv" "ofxOpenCv" "ofxKinect" "ofxAssimpModelLoader" "ofxSvg" "ofxSvg" "ofxPoco" "ofxPoco")
    elif [ "$PLATFORM" == "vs" ]; then
        addonslibs=("opencv" "ippicv" "libusb" "assimp" "libxml2" "svgtiny" "poco")
        addons=("ofxOpenCv" "ofxOpenCv" "ofxKinect" "ofxAssimpModelLoader" "ofxSvg" "ofxSvg" "ofxPoco")
    elif [ "$PLATFORM" == "ios" ] || [ "$PLATFORM" == "tvos" ]; then
        addonslibs=("opencv" "ippicv" "assimp" "libxml2" "svgtiny" "poco" "openssl")
        addons=("ofxOpenCv" "ofxOpenCv" "ofxAssimpModelLoader" "ofxSvg" "ofxSvg" "ofxPoco" "ofxPoco")
    else
        addonslibs=("opencv" "ippicv" "assimp" "libxml2" "svgtiny" "poco")
        addons=("ofxOpenCv" "ofxOpenCv" "ofxAssimpModelLoader" "ofxSvg" "ofxSvg" "ofxPoco")
    fi

    for ((i=0;i<${#addonslibs[@]};++i)); do
        if [ -e ${addonslibs[i]} ]; then
            echo "Copying ${addonslibs[i]} to ${addons[i]}"
            addon_path="$OF_LIBS/../addons/${addons[i]}/libs/${addonslibs[i]}"
            if [ $OVERWRITE -eq 1 ] && [ -e $addon_path ]; then
                echo "Removing old ${addonslibs[i]} libraries"
                rm -rf $addon_path
            fi
            mkdir -p $addon_path
            if ! command -v rsync &> /dev/null; then      
                cp -a ${addonslibs[i]}/* $addon_path  
            else
                rsync -a ${addonslibs[i]}/ $addon_path/
            fi
            rm -rf ${addonslibs[i]}
        fi
    done
}

if [ ${BUILD_LIBRARIES} == 1 ]; then
   build_libraries
fi

if [ ${MOVE_LIBRARIES} == 1 ]; then

   echo "Moving Latest Libraries to openFrameworks core libs directory"
   move_libraries

   echo "Updating and moving addons to correct directories from libs directory"
   sort_libraries
fi

echo "Apothecary openFrameworks Build and installation complete."
