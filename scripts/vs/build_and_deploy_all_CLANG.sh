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

if [ -z "${MULTITHREADED_TYPE+x}" ]; then # MD (MutliDynamic) # MT (Multi)
    MULTITHREADED_TYPE=MD 
fi

if [ -z ${CALLING_CONVENTION+x} ]; then # Gz (__stdcall) # Gd (__cdecl) # Gr (__fastcall) # Gv ( __vectorcall )
    CALLING_CONVENTION="Gz" #these changes effect how libraries are bound/loaded and called 
fi

if [ -z "${VS_TYPE+x}" ]; then # Professional # Enterprise # Community
    export VS_TYPE=Community 
fi

if [ -z "${VS_COMPILER+x}" ]; then # MSVC / # Clang LLVM 
    export VS_COMPILER=LLVM
fi

if [ -z "${VS_HOST+x}" ]; then
    VS_HOST=amd64 
fi

if [ -z "${PLATFORM+x}" ]; then
    PLATFORM=vs
fi

if [ -z "${OVERWRITE+x}" ]; then
    OVERWRITE=1
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

${SCRIPT_DIR}/build_and_deploy_all.sh