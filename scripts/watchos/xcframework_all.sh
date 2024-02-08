#!/bin/bash

# Apothecary ROOT dir relative

SCRIPT_DIR=$(cd $(dirname "$0"); pwd -P)
ROOT=$(cd $(dirname "${SCRIPT_DIR}/../../../"); pwd -P)
APOTHECARY_PATH=${ROOT}/apothecary

# Set OF_ROOT directory
if [ -z "${OF_ROOT+x}" ]; then
    export OF_ROOT=$(cd "$(dirname "$ROOT/../../../")"; pwd -P)
fi

# openFrameworks libs directory
OF_LIBS=${OF_ROOT}/libs
OF_ADDONS=${OF_ROOT}/addons

# control 
if [ -z "${BUILD_LIBRARIES+x}" ]; then
    BUILD_LIBRARIES=1
fi

if [ -z "${MOVE_LIBRARIES+x}" ]; then
    MOVE_LIBRARIES=0
fi

if [ -z "${PLATFORM+x}" ]; then
    PLATFORM=watchos
fi

# if [ -z "${ARCH+x}" ]; then
#     ARCH=x86_64
# fi

if [ -z "${OVERWRITE+x}" ]; then
    OVERWRITE=1
fi

if [ -z "${XCFRAMEWORK+x}" ]; then
    XCFRAMEWORK=1
fi



# Set OUTPUT_FOLDER for the build
export OUTPUT_FOLDER="${ROOT}/out"

echo "Verify Locations:"
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "OF_LIBS: $OF_LIBS"
echo "OF_ADDONS: $OF_ADDONS"
echo "ROOT: $ROOT"
echo "APOTHECARY_PATH: $APOTHECARY_PATH"
echo "OUTPUT_FOLDER: $OUTPUT_FOLDER"

# move built libraries to openFrameworks libs directory
move_libraries() {

    echo "moving libraries from apothecary out to $OF_LIBS"


        echo "Source Folder: ${OUTPUT_FOLDER}"
        echo "Destination Folder: ${OF_LIBS}"

        if ! command -v rsync &> /dev/null; then
            echo "Using cp to move libraries..."
            for file in "${OUTPUT_FOLDER}"/*; do
                cp -av "$file" "${OF_LIBS}/"
            done
        else
            echo "Using rsync to move libraries..."
            for file in "${OUTPUT_FOLDER}"/*; do
                rsync -av "$file" "${OF_LIBS}/"
            done
        fi


    echo "Libraries moved to openFrameworks libs directory."
}

build_xcframework() {
    echo "build_xcframework"
    ${SCRIPT_DIR}/build_xcframework.sh
    if [ $? -ne 0 ]; then
        echo "Error building build_xcframework $PLATFORM$ARCHE"
        exit 1
    fi
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
        if [ -e ${OF_LIBS}/${addonslibs[i]} ]; then
            echo "Copying ${addonslibs[i]} to ${addons[i]}"
            addon_path="${OF_ADDONS}/${addons[i]}/libs/${addonslibs[i]}"
            if [ $OVERWRITE -eq 1 ] && [ -e $addon_path ]; then
                echo "Removing old ${addonslibs[i]} libraries"
                rm -rf ${addon_path}
            fi
            mkdir -p $addon_path
            if ! command -v rsync &> /dev/null; then      
                cp -av ${OF_LIBS}/${addonslibs[i]}/* ${addon_path}
            else
                rsync -av ${OF_LIBS}/${addonslibs[i]}/ ${addon_path}/
            fi
            rm -rf ${OF_LIBS}/${addonslibs[i]}
        else
            echo "Addon not found at ${OF_LIBS}/${addonslibs[i]}"
        fi
    done
}


if [ ${XCFRAMEWORK} == 1 ]; then
   build_xcframework
fi

if [ ${MOVE_LIBRARIES} == 1 ]; then

   echo "========================"

   echo "Moving Latest Libraries to openFrameworks core libs directory"
   move_libraries

   echo "========================"

   echo "Updating and moving addons to correct directories from libs directory"
   sort_libraries

   echo "========================"
fi

echo "Apothecary openFrameworks Build and installation complete."

