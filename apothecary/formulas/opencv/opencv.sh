#!/usr/bin/env bash
#
# OpenCV
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system

FORMULA_TYPES=("osx" "ios" "catos" "xros" "tvos" "vs" "android" "emscripten" "linux" )
FORMULA_DEPENDS=("zlib" "libpng")

# define the version
VER=4.11.0
BUILD_ID=5
DEFINES=""
FRAMEWORKS=""
FILE_VERSION=4110

# tools for git use
GIT_URL=https://github.com/opencv/opencv
GIT_TAG=$VER

GIT_CONTRIB_URL=https://github.com/opencv/opencv_contrib
VER_CONTRIB=$VER

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"
    downloader $GIT_URL/archive/refs/tags/$VER.tar.gz
    tar -xzf $VER.tar.gz
    mv opencv-$VER opencv
    rm $VER.tar.gz

    downloader $GIT_CONTRIB_URL/archive/refs/tags/$VER.tar.gz
    tar -xzf $VER.tar.gz
    mv opencv_contrib-$VER opencv/opencv_contrib
    rm $VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : # noop

    #no idea why we are building iOS stuff on Windows - but this might fix it
    if [ "$TYPE" == "vs" ]; then
        rm -rf modules/objc_bindings_generator
        rm -rf modules/objc
    fi

    rm -f ./modules/imgcodecs/src/ios_conversions.mm
    cp $FORMULA_DIR/ios_conversions.mm ./modules/imgcodecs/src/ios_conversions.mm
}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        # sed -i'' -e  "s|return __TBB_machine_fetchadd4(ptr, 1) + 1L;|return __atomic_fetch_add(ptr, 1L, __ATOMIC_SEQ_CST) + 1L;|" 3rdparty/ittnotify/src/ittnotify/ittnotify_config.h

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt || true
        CORE_DEFS="
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_STANDARD=${C_STANDARD} \
		-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
		-DCMAKE_CXX_STANDARD_REQUIRED=ON \
		-DCMAKE_CXX_EXTENSIONS=OFF \
		-DBUILD_SHARED_LIBS=OFF \
		-DCMAKE_INSTALL_PREFIX=Release \
		-DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
		-DCMAKE_INSTALL_INCLUDEDIR=include \
		-DZLIB_ROOT=${ZLIB_ROOT} \
		-DZLIB_LIBRARY=${ZLIB_LIBRARY} \
		-DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
		-DPNG_ROOT=${LIBPNG_ROOT} \
		-DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
		-DPNG_LIBRARY=${LIBPNG_LIBRARY}"

        DEFINES="
		-DBUILD_DOCS=OFF \
		-DENABLE_BUILD_HARDENING=ON \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_FAT_JAVA_LIB=OFF \
		-DBUILD_JASPER=OFF \
		-DBUILD_PACKAGE=OFF \
		-DBUILD_opencv_java=OFF \
		-DBUILD_opencv_python=OFF \
		-DBUILD_opencv_python2=OFF \
		-DBUILD_opencv_python3=OFF \
		-DBUILD_opencv_apps=OFF \
		-DBUILD_opencv_highgui=ON \
		-DBUILD_opencv_imgcodecs=ON \
		-DBUILD_opencv_stitching=ON \
		-DBUILD_opencv_calib3d=ON \
		-DBUILD_opencv_objdetect=ON \
		-DOPENCV_ENABLE_NONFREE=OFF \
		-DWITH_PNG=ON \
		-DBUILD_PNG=OFF \
		-DWITH_1394=OFF \
		-DWITH_IMGCODEC_HDR=ON \
		-DWITH_CARBON=OFF \
		-DWITH_JPEG=OFF \
		-DWITH_TIFF=ON \
		-DWITH_FFMPEG=ON \
		-DWITH_QUIRC=ON \
		-DWITH_GIGEAPI=OFF \
		-DBUILD_OBJC=ON \
		-DWITH_CUDA=OFF \
		-DWITH_METAL=ON
		-DWITH_CUFFT=OFF \
		-DWITH_JASPER=OFF \
		-DWITH_LIBV4L=OFF \
		-DWITH_IMAGEIO=OFF \
		-DWITH_IPP=OFF \
		-DWITH_OPENCL=OFF \
		-DWITH_OPENNI=OFF \
		-DWITH_OPENNI2=OFF \
		-DWITH_QT=OFF \
		-DWITH_QUICKTIME=OFF \
		-DWITH_V4L=OFF \
		-DWITH_PVAPI=OFF \
		-DWITH_OPENEXR=OFF \
		-DWITH_EIGEN=ON \
		-DBUILD_TESTS=OFF \
		-DWITH_LAPACK=OFF \
		-DWITH_WEBP=OFF \
		-DWITH_GPHOTO2=OFF \
		-DWITH_VTK=OFF \
		-DWITH_CAP_IOS=ON \
		-DWITH_WEBP=ON \
		-DWITH_GTK=OFF \
		-DWITH_GTK_2_X=OFF \
		-DWITH_MATLAB=OFF \
		-DWITH_OPENVX=ON \
		-DWITH_ADE=OFF \
		-DWITH_TBB=OFF \
		-DWITH_OPENGL=OFF \
		-DWITH_GSTREAMER=OFF \
		-DVIDEOIO_PLUGIN_LIST=gstreamer \
		-DWITH_IPP=OFF \
		-DWITH_IPP_A=OFF \
		-DBUILD_ZLIB=OFF \
		-DWITH_ITT=OFF \
		-DWITH_CAROTENE=OFF \
		-DBUILD_TESTS=OFF "

        if [[ "$ARCH" =~ ^(arm64|SIM_arm64|arm64_32)$ ]]; then
            # ARM64 targets: Enable NEON
            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='NEON' -DCPU_DISPATCH='' -DCV_DISABLE_OPTIMIZATION=OFF  -DPNG_ARM_NEON=on"
        else
            # x86_64 targets: Enable SSE2 as baseline, dispatch higher SSE/AVX
            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='SSE2' -DCPU_DISPATCH='SSE4_1;SSE4_2;AVX' -DCV_DISABLE_OPTIMIZATION=OFF"
        fi

        if [[ "$TYPE" =~ ^(tvos|watchos)$ ]]; then
            if [[ "$ARCH" =~ ^(arm64|SIM_arm64|arm64_32)$ ]]; then
                EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=OFF  -DCPU_BASELINE='' -DCPU_DISPATCH=''  -DPNG_ARM_NEON=off"
            fi
        fi


        if [[ "$TYPE" =~ ^(tvos|xros|watchos|catos)$ ]]; then
            EXTRA_DEFS="$EXTRA_DEFS -DBUILD_opencv_videoio=OFF -DBUILD_opencv_videostab=OFF"
        else
            EXTRA_DEFS="-DBUILD_opencv_videoio=ON -DBUILD_opencv_videostab=ON"
        fi

        FRAMEWORKS="-framework Foundation -framework AVFoundation -framework CoreFoundation -framework CoreVideo"

        cmake .. ${CORE_DEFS} ${DEFINES} ${EXTRA_DEFS} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=ON \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_FAST_MATH=OFF \
            -DCMAKE_EXE_LINKER_FLAGS="${FRAMEWORKS}" \
            -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -fPIC -DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -fPIC -Wno-implicit-function-declaration -DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DENABLE_STRICT_TRY_COMPILE=ON \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE}

        cmake --build . --config Release -j${PARALLEL_MAKE}
        cmake --install . --config Release

        cd ..

    elif [ "$TYPE" == "vs" ]; then
        echoInfo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echoInfo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt || true

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.lib"

        FLAGS_RELEASE=$(echo $FLAGS_RELEASE | sed 's/-DUNICODE//g' | sed 's/-D_UNICODE//g')
        FLAGS_DEBUG=$(echo $FLAGS_DEBUG | sed 's/-DUNICODE//g' | sed 's/-D_UNICODE//g')

        export DEFINES="
				-DCMAKE_C_STANDARD=${C_STANDARD} \
				-DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
                -DCMAKE_CXX_STANDARD_REQUIRED=ON \
                -DCMAKE_CXX_EXTENSIONS=OFF \
                -DCMAKE_INSTALL_PREFIX=install \
                -DCMAKE_INSTALL_INCLUDEDIR=include \
                -DOPENCV_ENABLE_NONFREE=OFF \
                -DCMAKE_INSTALL_LIBDIR="lib" \
                -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
                -DWITH_OPENCLAMDBLAS=OFF \
                -DBUILD_TESTS=OFF \
                -DWITH_FFMPEG=ON \
                -DWITH_WIN32UI=OFF \
                -DBUILD_PACKAGE=OFF \
                -DWITH_JASPER=OFF \
                -DWITH_GIGEAPI=OFF \
                -DWITH_JPEG=OFF \
                -DBUILD_WITH_DEBUG_INFO=OFF \
                -DBUILD_TIFF=OFF \
                -DBUILD_JPEG=OFF \
                -DWITH_OPENCLAMDFFT=OFF \
                -DBUILD_opencv_java=OFF \
                -DBUILD_opencv_python=OFF \
                -DBUILD_opencv_python2=OFF \
                -DBUILD_opencv_python3=OFF \
                -DBUILD_NEW_PYTHON_SUPPORT=OFF \
                -DBUILD_opencv_objdetect=ON \
                -DHAVE_opencv_python3=ON \
                -DHAVE_opencv_python=ON \
                -DHAVE_opencv_python2=OFF \
                -DBUILD_opencv_apps=OFF \
                -DBUILD_opencv_videoio=ON \
                -DBUILD_opencv_videostab=ON \
                -DWITH_GSTREAMER=OFF \
                -DVIDEOIO_PLUGIN_LIST=gstreamer \
                -DBUILD_opencv_highgui=OFF \
                -DBUILD_opencv_imgcodecs=ON \
                -DBUILD_opencv_stitching=ON \
                -DBUILD_opencv_calib3d=ON \
                -DBUILD_PERF_TESTS=OFF \
                -DBUILD_JASPER=OFF \
                -DBUILD_DOCS=OFF \
                -DWITH_TIFF=OFF \
                -DWITH_1394=OFF \
                -DWITH_EIGEN=OFF \
                -DBUILD_OPENEXR=OFF \
                -DWITH_DSHOW=OFF \
                -DWITH_VFW=OFF \
                -DWITH_PNG=ON \
                -DBUILD_PNG=OFF \
                -DWITH_OPENCL=OFF \
                -DWITH_PVAPI=OFF\
                -DBUILD_OBJC=OFF \
                -DWITH_OPENEXR=OFF \
                -DWITH_OPENGL=ON \
                -DWITH_OPENVX=OFF \
                -DWITH_ADE=OFF \
                -DWITH_FFMPEG=OFF \
                -DWITH_GPHOTO2=OFF \
                -DWITH_IMAGEIO=OFF \
                -DWITH_IPP=OFF \
                -DWITH_IPP_A=OFF \
                -DWITH_OPENNI=OFF \
                -DWITH_OPENNI2=OFF \
                -DWITH_QT=OFF \
                -DWITH_QUICKTIME=OFF \
                -DWITH_V4L=OFF \
                -DWITH_LIBV4L=OFF \
                -DWITH_MATLAB=OFF \
                -DWITH_OPENCLCLAMDBLAS=OFF \
                -DWITH_OPENCLCLAMDFFT=OFF \
                -DWITH_OPENCL_SVM=OFF \
                -DWITH_LAPACK=OFF \
                -DBUILD_ZLIB=OFF \
                -DWITH_ZLIB=ON \
                -DWITH_DIRECTX=ON \
                -DWITH_MSMF=ON \
                -DWITH_DSHOW=ON \
                -DWITH_MSMF_DXVA=OFF \
                -DWITH_WEBP=OFF \
                -DWITH_VTK=OFF \
                -DWITH_OPENMP=OFF \
                -DWITH_PVAPI=OFF \
                -DWITH_GTK=OFF \
                -DWITH_NVCUVID=OFF \
                -DWITH_NVCUVENC=OFF \
                -DENABLE_SOLUTION_FOLDERS=OFF \
                -DWITH_GTK_2_X=OFF"

        if [[ "$ARCH" =~ ^(arm64ec|arm64)$ ]]; then  # ARM64 on Windows
            export EXTRA_DEFS="-DCV_DISABLE_OPTIMIZATION=OFF \
                        -DCV_ENABLE_INTRINSICS=OFF \
                        -DCPU_BASELINE='NEON;VFPV3' \
                        -DCPU_DISPATCH=''
                        -DWITH_NEON=OFF \
                        -DENABLE_NEON=OFF \
                        -DPNG_ARM_NEON=off \
                        -DPNG_INTEL_SSE=off \
                        -DBUILD_opencv_rgbd=OFF"
        else  # x86/x64 on Windows
            export EXTRA_DEFS="-DCV_DISABLE_OPTIMIZATION=OFF \
                        -DCPU_BASELINE='SSE2' \
                        -DCPU_DISPATCH='SSE4_1;SSE4_2'
                        -DCV_ENABLE_INTRINSICS=ON \
                        -DPNG_ARM_NEON=off \
                        -DPNG_INTEL_SSE=off"
        fi

        if [ "${OPENCV_CUDA:-0}" == "1" ]; then
            echoInfo "Building OpenCV with CUDA"
            CUDA_VERSION=${CUDA_VERSION:-12.8}
            DRIVE=${DRIVE:-C:}
            DEFAULT_CUDA_PATH="${DRIVE}\\Program Files\\NVIDIA GPU Computing Toolkit\\CUDA\\v${CUDA_VERSION}"
            #DCUDA_TOOLKIT_ROOT_DIR=\"${CUDA_PATH:-$DEFAULT_CUDA_PATH}\" \
            export DEFINES="$DEFINES \
                -DWITH_CUDA=ON \
                -DCUDA_ARCH_BIN='7.5;8.6;8.9;9.0' \
                -DCUDA_ARCH_PTX='9.0' \
                -DBUILD_opencv_cudacodec=ON \
                -DWITH_CUDNN=ON \
                -DWITH_CUBLAS=ON \
                -DWITH_CUFFT=ON \
                -DENABLE_FAST_MATH=ON"
        else
            export DEFINES="$DEFINES \
                -DWITH_CUDA=OFF \
                -DWITH_CUDNN=OFF \
                -DWITH_CUBLAS=OFF \
                -DWITH_CUFFT=OFF"
        fi

        if [ "${OPENCV_STATIC:-0}" = "1" ]; then
            echoInfo "Building with OPENCV_STATIC"
            export DEFINES="${DEFINES} \
            -DBUILD_WITH_STATIC_CRT=ON \
            -DUSE_STATIC_CRT=ON \
            -DBUILD_SHARED_LIBS=OFF"
            if [ $MULTITHREADED_TYPE == "MD" ]; then
                sed -i 's/\/MT/\/MD/g; s/\/MTd/\/MDd/g' ../CMakeLists.txt
            fi
        else
            echoInfo "Building OpenCV Debug"
            export DEFINES="${DEFINES} -DBUILD_WITH_STATIC_CRT=OFF -DUSE_STATIC_CRT=OFF -DBUILD_SHARED_LIBS=ON"
            cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Debug \
            -DCMAKE_BUILD_TYPE="Debug" \
            -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
            ${EXTRA_DEFS} \
            ${CMAKE_WIN_SDK} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_PNG=OFF \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY}
            cmake --build . --target install --config Debug
            mv Debug ..
            mv 3rdparty/lib/Debug ../Debug3rd

            rm -f CMakeCache.txt *.a *.o *.lib *.js
            cd ..
            if [ -d "build_${TYPE}_${PLATFORM}" ]; then
                rm -r build_${TYPE}_${PLATFORM}
            fi
            mkdir -p "build_${TYPE}_${PLATFORM}"
            cd "build_${TYPE}_${PLATFORM}"
            rm -f CMakeCache.txt || true
        fi

        echoInfo "Building OpenCV Release"
        cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE="Release" \
            -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            ${EXTRA_DEFS} \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DBUILD_PNG=OFF \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            ${CMAKE_WIN_SDK}
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..

        if [ -d "Debug" ]; then
            mv "Debug" build_${TYPE}_${PLATFORM}/Debug
            mv "Debug3rd" build_${TYPE}_${PLATFORM}/3rdparty/lib/Debug
        fi

    elif [ "$TYPE" == "android" ]; then
        export ANDROID_NDK=${NDK_ROOT}
        if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
            local BUILD_FOLDER="build_androREid_arm"
            local BUILD_SCRIPT="cmake_android_arm.sh"
        elif [ "$ABI" = "arm64-v8a" ]; then
            local BUILD_FOLDER="build_android_arm64"
            local BUILD_SCRIPT="cmake_android_arm64.sh"
        elif [ "$ABI" = "x86_64" ]; then
            local BUILD_FOLDER="build_android_x86_64"
            local BUILD_SCRIPT="cmake_android_x86_64.sh"
        elif [ "$ABI" = "x86" ]; then
            local BUILD_FOLDER="build_android_x86"
            local BUILD_SCRIPT="cmake_android_x86.sh"
        fi
        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        rm -rf $BUILD_FOLDER
        mkdir $BUILD_FOLDER
        cd $BUILD_FOLDER

        if [ "$ABI" = "armeabi-v7a" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=TRUE"
        elif [ $ABI = "arm64-v8a" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        elif [ "$ABI" = "x86_64" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        elif [ "$ABI" = "x86" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        fi

        export ANDROID_NATIVE_API_LEVEL=21

        echo ${ANDROID_NDK}
        pwd

        if [[ "$ABI" =~ ^(armeabi-v7a|arm64-v8a)$ ]]; then # Enable NEON with VFPv3

            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='NEON;VFPV3' -DCPU_DISPATCH=''"
        else
            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='SSE2' -DCPU_DISPATCH='SSE4_1;SSE4_2'"
        fi
        rm -f CMakeCache.txt || true
        cmake \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_ABI="${ABI}" \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
            -DCMAKE_CXX_FLAGS="" \
            -DCMAKE_C_FLAGS="" \
            -DCMAKE_SYSROOT=$SYSROOT \
            -DANDROID_NDK=$NDK_ROOT \
            -DANDROID_ABI=$ABI \
            -DOPENCV_ENABLE_NONFREE=OFF \
            -DCMAKE_ANDROID_ARCH_ABI=$ABI \
            -DANDROID_STL=c++_shared \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
            -DANDROID_ABI=${ABI} \
            -DBUILD_ANDROID_PROJECTS=OFF \
            -DBUILD_ANDROID_EXAMPLES=OFF \
            -DBUILD_KOTLIN_EXTENSIONS=ON \
            -DBUILD_opencv_objdetect=ON \
            -DBUILD_opencv_video=ON \
            -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
            -DBUILD_opencv_videoio=ON \
            -DBUILD_opencv_features2d=ON \
            -DBUILD_opencv_flann=OFF \
            -DBUILD_opencv_highgui=ON \
            -DBUILD_opencv_ml=ON \
            -DBUILD_opencv_photo=OFF \
            -DBUILD_opencv_python=OFF \
            -DBUILD_opencv_shape=OFF \
            -DBUILD_opencv_stitching=OFF \
            -DBUILD_opencv_superres=OFF \
            -DBUILD_opencv_ts=OFF \
            -DBUILD_opencv_videostab=OFF \
            -DBUILD_opencv_calib3d=ON \
            -DWITH_MATLAB=OFF \
            -DWITH_CUDA=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_DOCS=OFF \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_FAT_JAVA_LIB=OFF \
            -DBUILD_JASPER=OFF \
            -DBUILD_PACKAGE=OFF \
            -DBUILD_opencv_java=OFF \
            -DBUILD_opencv_apps=OFF \
            -DBUILD_JPEG=OFF \
            -DBUILD_PNG=OFF \
            -DHAVE_opencv_androidcamera=ON \
            -DWITH_CAROTENE=OFF \
            -DWITH_CPUFEATURES=OFF \
            -DWITH_TIFF=ON \
            -DWITH_OPENEXR=OFF \
            -DWITH_1394=OFF \
            -DWITH_JPEG=OFF \
            -DWITH_PNG=OFF \
            -DWITH_FFMPEG=OFF \
            -DWITH_OPENCL=OFF \
            -DWITH_GIGEAPI=OFF \
            -DWITH_CUDA=OFF \
            -DWITH_CUFFT=OFF \
            -DWITH_JASPER=OFF \
            -DWITH_IMAGEIO=OFF \
            -DWITH_IPP=OFF \
            -DWITH_OPENNI=OFF \
            -DWITH_QT=OFF \
            -DWITH_V4L=OFF \
            -DWITH_PVAPI=OFF \
            -DWITH_EIGEN=OFF \
            -DWITH_ITT=OFF \
            -DENABLE_VFPV3=ON \
            ${EXTRA_DEFS} \
            -DBUILD_TESTS=OFF \
            -DANDROID_NDK=${NDK_ROOT} \
            -DCMAKE_BUILD_TYPE=Release \
            -DANDROID_STL=c++_shared \
            -DANDROID_PLATFORM=$ANDROID_PLATFORM \
            -DBUILD_PERF_TESTS=OFF ..
        make -j${PARALLEL_MAKE}
        make install

    elif [[ "$TYPE" =~ ^(linux)$ ]]; then
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        CORE_DEFS="
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_STANDARD=${C_STANDARD} \
        -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_INSTALL_PREFIX=Release \
        -DZLIB_ROOT=${ZLIB_ROOT} \
        -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
        -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
        -DPNG_ROOT=${LIBPNG_ROOT} \
        -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
        -DPNG_LIBRARY=${LIBPNG_LIBRARY}"

    DEFINES="
        -DBUILD_DOCS=OFF \
        -DENABLE_BUILD_HARDENING=ON \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_opencv_highgui=ON \
        -DBUILD_opencv_imgcodecs=ON \
        -DBUILD_opencv_stitching=ON \
        -DBUILD_opencv_calib3d=ON \
        -DBUILD_opencv_objdetect=ON \
        -DBUILD_opencv_videoio=ON \
        -DBUILD_opencv_videostab=ON \
        -DOPENCV_ENABLE_NONFREE=OFF \
        -DWITH_PNG=ON \
        -DBUILD_PNG=OFF \
        -DWITH_FFMPEG=ON \
        -DWITH_GSTREAMER=ON \
        -DWITH_V4L=ON \
        -DWITH_EIGEN=ON \
        -DBUILD_TESTS=OFF \
        -DWITH_OPENGL=OFF \
        -DWITH_VULKAN=OFF \
        -DWITH_OPENCL=OFF \
        -DWITH_QT=OFF \
        -DWITH_GTK=ON"

        if [ "${OPENCV_CUDA:-0}" == "1" ]; then
            CUDA_VERSION=${CUDA_VERSION:-12.8}
            DEFAULT_CUDA_PATH="/usr/local/cuda-${CUDA_VERSION}"
            CUDA_PATH=${CUDA_PATH:-$DEFAULT_CUDA_PATH}
            if [ ! -d "$CUDA_PATH" ]; then
                echo "Error: CUDA Toolkit not found at $CUDA_PATH. Please set CUDA_PATH or install CUDA."
                exit 1
            fi
            DEFINES="${DEFINES} \
                -DWITH_CUDA=ON \
                -DCUDA_TOOLKIT_ROOT_DIR=${CUDA_PATH} \
                -DCUDA_FAST_MATH=ON \
                -DWITH_CUBLAS=ON \
                -DWITH_CUFFT=ON \
                -DCUDA_ARCH_BIN='6.1;7.5;8.6;8.9;9.0' \
                -DCUDA_ARCH_PTX='9.0'"
        fi

        cmake .. ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DPLATFORM=$PLATFORM \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DPNG_HARDWARE_OPTIMIZATIONS=ON \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "emscripten" ]; then


        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${LIBPNG_ROOT}/lib/$TYPE/$PLATFORM:${ZLIB_ROOT}/lib/$TYPE/$PLATFORM"

        mkdir -p build_${TYPE}_${PLATFORM}
        cd build_${TYPE}_${PLATFORM}
        find ./ -name "*.o" -type f -delete
        rm -f CMakeCache.txt || true
        rm -f CMakeCache.txt *.a *.o *.a

        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B build \
            -DCMAKE_TOOLCHAIN_FILE=$EMSDK/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ ${FLAG_RELEASE} -msimd128" \
            -DCMAKE_C_FLAGS="-I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ ${FLAG_RELEASE} -msimd128" \
            -DCMAKE_CXX_EXTENSIONS=ON \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE="Release" \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCPU_BASELINE='WASM_SIMD' \
            -DCPU_DISPATCH='' \
            -DCV_ENABLE_INTRINSICS=ON \
            -DCV_TRACE=OFF \
            -DOPENCV_ENABLE_NONFREE=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DBUILD_DOCS=OFF \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_FAT_JAVA_LIB=OFF \
            -DBUILD_JASPER=OFF \
            -DBUILD_PACKAGE=OFF \
            -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
            -DBUILD_TESTS=OFF \
            -DBUILD_PERF_TESTS=OFF \
            -DWITH_QUIRC:BOOL=OFF \
            -DBUILD_CUDA_STUBS=OFF \
            -DBUILD_opencv_objc_bindings_generator=NO \
            -DBUILD_opencv_java=OFF \
            -DBUILD_opencv_python=OFF \
            -DBUILD_opencv_apps=OFF \
            -DBUILD_opencv_videoio=OFF \
            -DBUILD_opencv_videostab=OFF \
            -DBUILD_opencv_highgui=OFF \
            -DBUILD_opencv_imgcodecs=ON \
            -DBUILD_opencv_python2=OFF \
            -DBUILD_opencv_gapi=OFF \
            -DBUILD_opencv_ml=OFF \
            -DBUILD_opencv_rgbd=OFF \
            -DBUILD_opencv_shape=OFF \
            -DBUILD_opencv_highgui=OFF \
            -DBUILD_opencv_superres=OFF \
            -DBUILD_opencv_stitching=OFF \
            -DBUILD_opencv_python2=OFF \
            -DBUILD_opencv_python3=OFF \
            -DBUILD_opencv_objdetect=ON \
            -DBUILD_opencv_features2d=ON \
            -DBUILD_opencv_flann=ON \
            -DBUILD_opencv_photo=OFF \
            -DBUILD_opencv_python=OFF \
            -DBUILD_opencv_shape=OFF \
            -DBUILD_opencv_stitching=OFF \
            -DBUILD_opencv_superres=OFF \
            -DBUILD_opencv_ts=OFF \
            -DBUILD_opencv_calib3d=ON \
            -DWITH_MATLAB=OFF \
            -DWITH_CUDA=OFF \
            -DWITH_TIFF=OFF \
            -DWITH_OPENEXR=OFF \
            -DWITH_OPENGL=ON \
            -DWITH_OPENVX=ON \
            -DWITH_1394=OFF \
            -DWITH_ADE=OFF \
            -DWITH_JPEG=OFF \
            -DWITH_PNG=OFF \
            -DWITH_FFMPEG=OFF \
            -DWITH_GIGEAPI=OFF \
            -DWITH_CUDA=OFF \
            -DWITH_CUFFT=OFF \
            -DWITH_GIGEAPI=OFF \
            -DWITH_GPHOTO2=OFF \
            -DWITH_GSTREAMER=ON \
            -DWITH_GSTREAMER_0_10=OFF \
            -DWITH_JASPER=OFF \
            -DWITH_IMAGEIO=OFF \
            -DWITH_IPP=OFF \
            -DWITH_IPP_A=OFF \
            -DWITH_TBB=OFF \
            -DWITH_PTHREADS_PF=OFF \
            -DWITH_OPENNI=OFF \
            -DWITH_OPENNI2=OFF \
            -DWITH_QT=OFF \
            -DWITH_QUICKTIME=OFF \
            -DWITH_V4L=OFF \
            -DWITH_LIBV4L=OFF \
            -DWITH_MATLAB=OFF \
            -DWITH_OPENCL=OFF \
            -DWITH_OPENCLCLAMDBLAS=OFF \
            -DWITH_OPENCLCLAMDFFT=OFF \
            -DWITH_OPENCL_SVM=OFF \
            -DWITH_LAPACK=OFF \
            -DWITH_ITT=OFF \
            -DBUILD_ZLIB=OFF \
            -DWITH_ZLIB=ON \
            -DBUILD_PNG=OFF \
            -DWITH_WEBP=ON \
            -DWITH_VTK=OFF \
            -DWITH_PVAPI=OFF \
            -DWITH_EIGEN=OFF \
            -DWITH_GTK=OFF \
            -DWITH_GTK_2_X=OFF \
            -DWITH_OPENCLAMDBLAS=OFF \
            -DWITH_OPENCLAMDFFT=OFF \
            -DWASM=ON \
            -DBUILD_TESTS=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DBUILD_WASM_INTRIN_TESTS=OFF \
            -DBUILD_PERF_TESTS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY}
        # -G 'Unix Makefiles'

        cmake --build build --target install --config Release
        # $EMSDK/upstream/emscripten/emmake make -j${PARALLEL_MAKE}
        # $EMSDK/upstream/emscripten/emmake make install
    fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # prepare headers directory if needed
    mkdir -p $1/include
    # prepare libs directory if needed
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/etc
    . "$SECURE_SCRIPT"

    # copy license file
    if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
    mkdir -p $1/license

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

        mkdir -p $1/lib/$TYPE/$PLATFORM
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/opencv4/3rdparty/"*.a $1/lib/$TYPE/$PLATFORM/
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/"*.a $1/lib/$TYPE/$PLATFORM
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib/"*.dylib $1/lib/$TYPE/$PLATFORM 2>/dev/null || true

        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/opencv4/" $1/include/

        cp -Rv "build_${TYPE}_${PLATFORM}/Release/share/opencv4/"* $1/etc
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/share/licenses/"* $1/license
        cp -v LICENSE $1/license/

        secure "$1/lib/$TYPE/$PLATFORM/libopencv_core.a" "opencv.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    elif [ "$TYPE" == "vs" ]; then

        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/opencv2" $1/include/
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        OUTPUT_FOLDER=${BUILD_PLATFORM}

        if [ "${OPENCV_STATIC:-0}" = "1" ]; then
            cp -v "build_${TYPE}_${PLATFORM}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/staticlib/"*.lib $1/lib/$TYPE/$PLATFORM
            secure "$1/lib/$TYPE/$PLATFORM/opencv_core${FILE_VERSION}.lib" "opencv.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        else

            mkdir -p $1/lib/$TYPE/$PLATFORM/Debug
            mkdir -p $1/lib/$TYPE/$PLATFORM/Release

            mkdir -p $1/bin/$PLATFORM/Debug
            mkdir -p $1/bin/$PLATFORM/Release

            if [ -d "build_${TYPE}_${PLATFORM}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/lib/" ]; then

                cp -v "build_${TYPE}_${PLATFORM}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Release
                cp -v "build_${TYPE}_${PLATFORM}/Debug/${OUTPUT_FOLDER}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

                cp -v "build_${TYPE}_${PLATFORM}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/bin/"*.dll $1/bin/$PLATFORM/Release
                cp -v "build_${TYPE}_${PLATFORM}/Debug/${OUTPUT_FOLDER}/vc${VS_VER}/bin/"*.dll $1/bin/$PLATFORM/Debug
            else

                cp -v "build_${TYPE}_${PLATFORM}/Release/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Release
                cp -v "build_${TYPE}_${PLATFORM}/Debug/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

                cp -v "build_${TYPE}_${PLATFORM}/Release/bin/"*.dll $1/bin/$PLATFORM/Release
                cp -v "build_${TYPE}_${PLATFORM}/Debug/bin/"*.dll $1/bin/$PLATFORM/Debug

            fi

            cp -v "build_${TYPE}_${PLATFORM}/3rdparty/lib/Release/"*.lib $1/lib/$TYPE/$PLATFORM/Release
            cp -v "build_${TYPE}_${PLATFORM}/3rdparty/lib/Debug/"*.lib $1/lib/$TYPE/$PLATFORM/Debug
            cp -Rv "build_${TYPE}_${PLATFORM}/Release/etc/"* $1/etc

            secure "$1/lib/$TYPE/$PLATFORM/opencv_core${FILE_VERSION}.lib" "opencv.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        fi

    elif [ "$TYPE" == "android" ]; then
        if [ $ABI = armeabi-v7a ] || [ $ABI = armeabi ]; then
            local BUILD_FOLDER="build_android_arm"
        elif [ $ABI = arm64-v8a ]; then
            local BUILD_FOLDER="build_android_arm64"
        elif [ $ABI = x86 ]; then
            local BUILD_FOLDER="build_android_x86"
        elif [ $ABI = x86_64 ]; then
            local BUILD_FOLDER="build_android_x86_64"
        fi

        cp -r $BUILD_FOLDER/install/sdk/native/jni/include/opencv2 $1/include/
        cp -R include/opencv2 $1/include/
        cp -R modules/*/include/opencv2/* $1/include/opencv2/

        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -r $BUILD_FOLDER/install/sdk/native/staticlibs/$ABI/*.a $1/lib/$TYPE/$PLATFORM/
        cp -r $BUILD_FOLDER/install/sdk/native/3rdparty/libs/$ABI/*.a $1/lib/$TYPE/$PLATFORM/

        secure "$1/lib/$TYPE/$PLATFORM/libopencv_core.a" "opencv.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    elif [ "$TYPE" == "emscripten" ]; then
        mkdir -p $1/include/opencv2
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/include/
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -R include/opencv2 $1/include/
        cp -R modules/*/include/opencv2/* $1/include/opencv2/
        cp -v build_${TYPE}_${PLATFORM}/Release/lib/*.a $1/lib/$TYPE/$PLATFORM
        cp -v build_${TYPE}_${PLATFORM}/Release/lib/opencv4/3rdparty/*.a $1/lib/$TYPE/$PLATFORM
        secure "$1/lib/$TYPE/$PLATFORM/libopencv_core.a" "opencv.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

    fi
    cp -v LICENSE $1/license/

}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${ABI}" ]; then
            rm -r build_${TYPE}_${ABI}
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "opencv" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
