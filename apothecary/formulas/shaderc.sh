#! /bin/bash
#
# ShaderC
# tgfrerer
# compiling GLSL shader code into SPIR-V
#
# compile this with ./apothecary -a 64 update shaderc
# compile for windows visual studio: ./apothecary -a 64 -t vs update shaderc
#
# uses a CMake build system

FORMULA_TYPES=()

# define the shaderc version by sha
# Known good version is from: https://github.com/google/shaderc/blob/known-good/known_good.json
VER=ff84893dd52d28f0b1737d2635733d952013bd9c
#v2024.3

# tools for git use
GIT_URL=https://github.com/google/shaderc
GIT_TAG=$VER
DEFINES=""

# download the source code and unpack it into LIB_NAME
function download() {
    curl -Lk $GIT_URL/archive/$GIT_TAG.tar.gz -o shaderc-$GIT_TAG.tar.gz
    tar -xf shaderc-$GIT_TAG.tar.gz
    mv shaderc-$GIT_TAG shaderc
    rm shaderc*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    pushd third_party

    # load shaderc dependencies at known good revisions
    # we know working configurations from this file:
    # https://github.com/google/shaderc/blob/known-good/known_good.json

    if [[ ! -d "glslang" ]]; then
        git clone https://github.com/KhronosGroup/glslang.git glslang
        pushd glslang
        git checkout 46ef757e048e760b46601e6e77ae0cb72c97bd2f
        popd
    fi

    if [[ ! -d "spirv-tools" ]]; then
        echo "Cloning SPIRV-Tools repository..."
        git clone https://github.com/KhronosGroup/SPIRV-Tools.git spirv-tools
        pushd spirv-tools
        git checkout 01c8438ee4ac52c248119b7e03e0b021f853b51a
        popd
    fi

    if [[ ! -d "spirv-tools/external/spirv-headers" ]]; then
        git clone https://github.com/KhronosGroup/SPIRV-Headers.git spirv-tools/external/spirv-headers # rev: db5cf6176137003ca4c25df96f7c0649998c3499
        pushd spirv-tools/external/spirv-headers
        git checkout 2a9b6f951c7d6b04b6c21fe1bf3f475b68b84801
        popd
    fi

    popd
}

# executed inside the lib src dir
function build() {
    rm -f CMakeCache.txt
    LIBS_ROOT=$(realpath $LIBS_DIR)

    if [ "$TYPE" == "vs" ]; then

        echo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true
        DEFS="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=ON \
            -Dgtest_disable_pthreads=ON \
            -DSHADERC_SKIP_TESTS=ON \
            -DSHADERC_ENABLE_SHARED_CRT=ON"

        cmake .. ${DEFS} \
            -A "${PLATFORM}" \
            ${CMAKE_WIN_SDK} \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} " \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}"
        cmake --build . --config Release -j${PARALLEL_MAKE}
    else
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
            EXTRA_CONFIG=" "
        else
            EXTRA_CONFIG=" "
        fi
        # *nix build system

        mkdir -p build
        cd build

        DEFS="
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -Dgtest_disable_pthreads=ON \
            -DSHADERC_SKIP_TESTS=ON"

        cmake ..${DEFS} \
            -A "${PLATFORM}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}"
        cmake --build . --config Release -j${PARALLEL_MAKE}

    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    # prepare headers directory if needed
    mkdir -p $1/include/shaderc

    # prepare libs directory if needed
    mkdir -p $1/lib/$TYPE
    . "$SECURE_SCRIPT"
    if [ "$TYPE" == "vs" ]; then
        cp -Rv libshaderc/include/* $1/include
        cp -v "build_${TYPE}_${PLATFORM}/lib/Release/libshaderc_combined.lib" $1/lib/$TYPE/$PLATFORM/shaderc.lib
        secure "$1/lib/$TYPE/$PLATFORM/shaderc.lib" "shaderc.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    else
        pwd
        # Standard *nix style copy.
        # copy headers
        cp -Rv libshaderc/include/* $1/include
        # copy lib
        cp -v "build_${TYPE}_${PLATFORM}/lib/Release/libshaderc_combined.a" $1/lib/$TYPE/$PLATFORM/shaderc.a
        secure "$1/lib/$TYPE/$PLATFORM/shaderc.a" "shaderc.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    # copy license file
    rm -rf $1/license # remove any older files if exists
    mkdir -p $1/license
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        rm -f *.lib
    elif [ "$TYPE" == "linux" ]; then
        #statements
        cmake --clean .
    else
        make clean
    fi
}
