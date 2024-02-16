#!/usr/bin/env bash
#
# OpenCV
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "ios" "watchos" "catos" "xros" "tvos" "vs" "android" "emscripten" )

# define the version

VER=4.9.0


# tools for git use
GIT_URL=https://github.com/opencv/opencv.git
GIT_TAG=$VER

# these paths don't really matter - they are set correctly further down
local LIB_FOLDER="$BUILD_ROOT_DIR/opencv"
local LIB_FOLDER32="$LIB_FOLDER-32"
local LIB_FOLDER64="$LIB_FOLDER-64"
local LIB_FOLDER_IOS="$LIB_FOLDER-IOS"
local LIB_FOLDER_IOS_SIM="$LIB_FOLDER-IOSIM"


# download the source code and unpack it into LIB_NAME
function download() {
  curl -L https://github.com/opencv/opencv/archive/refs/tags/$VER.zip --output opencv-$VER.zip
  unzip -q opencv-$VER.zip
  mv opencv-$VER $1
  rm opencv*.zip
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
  : # noop
  
  #no idea why we are building iOS stuff on Windows - but this might fix it
  if [ "$TYPE" == "vs" ] ; then
    rm -rf modules/objc_bindings_generator
    rm -rf modules/objc
  fi
}

# executed inside the lib src dir
function build() {
  LIBS_ROOT=$(realpath $LIBS_DIR)
  if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    # sed -i'' -e  "s|return __TBB_machine_fetchadd4(ptr, 1) + 1L;|return __atomic_fetch_add(ptr, 1L, __ATOMIC_SEQ_CST) + 1L;|" 3rdparty/ittnotify/src/ittnotify/ittnotify_config.h
    
    ZLIB_ROOT="$LIBS_ROOT/zlib/"
    ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
    ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

    mkdir -p "build_${TYPE}_${PLATFORM}"
    cd "build_${TYPE}_${PLATFORM}"
    rm -f CMakeCache.txt || true
    DEFS="
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_LIBRARY} "
      if [[ "$ARCH" =~ ^(arm64|SIM_arm64|arm64_32)$ ]]; then
        EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=OFF -DENABLE_SSE=OFF -DENABLE_SSE2=OFF -DENABLE_SSE3=OFF -DENABLE_SSE41=OFF -DENABLE_SSE42=OFF -DENABLE_SSSE3=OFF -DWITH_CAROTENE=OFF"
      else 
        EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DENABLE_SSE=ON -DENABLE_SSE2=ON -DENABLE_SSE3=ON -DENABLE_SSE41=ON -DENABLE_SSE42=ON -DENABLE_SSSE3=ON"
      fi

    cmake .. ${DEFS} \
      -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
      -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
      -DPLATFORM=$PLATFORM \
      -DENABLE_BITCODE=OFF \
      -DENABLE_ARC=OFF \
      -DENABLE_VISIBILITY=OFF \
      -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
      -DENABLE_FAST_MATH=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -fPIC -Wno-implicit-function-declaration " \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -fPIC -Wno-implicit-function-declaration" \
      -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
      -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
      -DCMAKE_BUILD_TYPE="Release" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_python3=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_videostab=OFF \
      -DBUILD_opencv_highgui=ON \
      -DBUILD_opencv_imgcodecs=ON \
      -DBUILD_opencv_stitching=ON \
      -DBUILD_opencv_calib3d=ON \
      -DBUILD_opencv_objdetect=ON \
      -DWITH_1394=OFF \
      -DWITH_CARBON=OFF \
      -DWITH_JPEG=OFF \
      -DWITH_PNG=OFF \
      -DWITH_TIFF=OFF \
      -DWITH_FFMPEG=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DWITH_OPENCLAMDFFT=OFF \
      -DWITH_GIGEAPI=OFF \
      -DWITH_CUDA=OFF \
      -DWITH_CUFFT=OFF \
      -DWITH_JASPER=OFF \
      -DWITH_LIBV4L=OFF \
      -DWITH_IMAGEIO=OFF \
      -DWITH_IPP=OFF \
      -DWITH_OPENNI=OFF \
      -DWITH_QT=OFF \
      -DWITH_QUICKTIME=OFF \
      -DWITH_V4L=OFF \
      -DWITH_PVAPI=OFF \
      -DWITH_OPENEXR=ON \
      -DWITH_EIGEN=OFF \
      -DBUILD_TESTS=OFF \
      -DWITH_LAPACK=OFF \
      -DWITH_WEBP=OFF \
      -DWITH_GPHOTO2=OFF \
      -DWITH_VTK=OFF \
      -DWITH_GTK=OFF \
      -DWITH_GTK_2_X=OFF \
      -DWITH_MATLAB=OFF \
      -DWITH_GSTREAMER=OFF \
      -DWITH_GSTREAMER_0_10=OFF \
      -DWITH_GIGEAPI=OFF \
      -DWITH_OPENVX=OFF \
      -DWITH_1394=OFF \
      -DWITH_ADE=OFF \
      -DWITH_TBB=OFF \
      -DWITH_TIFF=OFF \
      -DWITH_OPENEXR=OFF \
      -DWITH_OPENGL=OFF \
      -DWITH_OPENVX=OFF \
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
      -DWITH_GSTREAMER=OFF \
      -DWITH_GSTREAMER_0_10=OFF \
      -DWITH_JASPER=OFF \
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
      -DWITH_OPENCL=OFF \
      -DWITH_OPENCLCLAMDBLAS=OFF \
      -DWITH_OPENCLCLAMDFFT=OFF \
      -DWITH_OPENCL_SVM=OFF \
      -DWITH_LAPACK=OFF \
      -DBUILD_ZLIB=OFF \
      -DWITH_WEBP=OFF \
      -DWITH_VTK=OFF \
      -DWITH_PVAPI=OFF \
      -DWITH_EIGEN=OFF \
      -DWITH_ITT=OFF \
      -DWITH_GTK=OFF \
      -DWITH_GTK_2_X=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DWITH_OPENCLAMDFFT=OFF \
      -DBUILD_TESTS=OFF \
      ${EXTRA_DEFS} \
      -DBUILD_PERF_TESTS=OFF \
      -DENABLE_STRICT_TRY_COMPILE=ON \
      -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} 
      cmake --build . --config Release
      cmake --install . --config Release
    cd ..

  elif [ "$TYPE" == "vs" ] ; then
    echoInfo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN - "${PLATFORM}""
    echoInfo "--------------------"
    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 
    mkdir -p "build_${TYPE}_${ARCH}"
    cd "build_${TYPE}_${ARCH}"
    rm -f CMakeCache.txt || true
    DEFS="
        -DCMAKE_C_STANDARD=17 \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=install \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
        -DBUILD_PNG=OFF \
        -DWITH_OPENCLAMDBLAS=OFF \
        -DBUILD_TESTS=OFF \
        -DWITH_CUDA=OFF \
        -DWITH_FFMPEG=OFF \
        -DWITH_WIN32UI=OFF \
        -DBUILD_PACKAGE=OFF \
        -DWITH_JASPER=OFF \
        -DWITH_OPENEXR=OFF \
        -DWITH_GIGEAPI=OFF \
        -DWITH_JPEG=OFF \
        -DBUILD_WITH_DEBUG_INFO=OFF \
        -DWITH_CUFFT=OFF \
        -DBUILD_TIFF=OFF \
        -DBUILD_JPEG=OFF \
        -DWITH_OPENCLAMDFFT=OFF \
        -DBUILD_WITH_STATIC_CRT=OFF \
        -DBUILD_opencv_java=OFF \
        -DBUILD_opencv_python=OFF \
        -DBUILD_opencv_python2=OFF \
        -DBUILD_opencv_python3=OFF \
        -DBUILD_NEW_PYTHON_SUPPORT=OFF \
        -DBUILD_opencv_objdetect=ON \
        -DHAVE_opencv_python3=OFF \
        -DHAVE_opencv_python=OFF \
        -DHAVE_opencv_python2=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_opencv_videoio=OFF \
        -DBUILD_opencv_videostab=OFF \
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
        -DWITH_PNG=OFF \
        -DWITH_OPENCL=OFF \
        -DWITH_PVAPI=OFF\
        -DBUILD_OBJC=OFF \
        -DWITH_TIFF=OFF \
        -DWITH_OPENEXR=OFF \
        -DWITH_OPENGL=OFF \
        -DWITH_OPENVX=OFF \
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
        -DWITH_GSTREAMER=OFF \
        -DWITH_GSTREAMER_0_10=OFF \
        -DWITH_JASPER=OFF \
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
        -DWITH_OPENCL=OFF \
        -DWITH_OPENCLCLAMDBLAS=OFF \
        -DWITH_OPENCLCLAMDFFT=OFF \
        -DWITH_OPENCL_SVM=OFF \
        -DWITH_LAPACK=OFF \
        -DBUILD_ZLIB=ON \
        -DWITH_WEBP=OFF \
        -DWITH_VTK=OFF \
        -DWITH_PVAPI=OFF \
        -DWITH_EIGEN=OFF \
        -DWITH_GTK=OFF \
        -DWITH_GTK_2_X=OFF \
        -DWITH_OPENCLAMDBLAS=OFF \
        -DWITH_OPENCLAMDFFT=OFF \
        -DBUILD_TESTS=OFF \
        -DCV_DISABLE_OPTIMIZATION=OFF"

      if [[ ${ARCH} == "arm64ec" || "${ARCH}" == "arm64" ]]; then
        EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=OFF -DENABLE_SSE=OFF -DENABLE_SSE2=OFF -DENABLE_SSE3=OFF -DENABLE_SSE41=OFF -DENABLE_SSE42=OFF -DENABLE_SSSE3=OFF"
      else 
        EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DENABLE_SSE=ON -DENABLE_SSE2=ON -DENABLE_SSE3=ON -DENABLE_SSE41=ON -DENABLE_SSE42=ON -DENABLE_SSSE3=ON"
      fi
    
    cmake .. ${DEFS} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}" \
        -DCMAKE_INSTALL_PREFIX=Debug \
        -DCMAKE_BUILD_TYPE="Debug" \
        -DCMAKE_CXX_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
        -DCMAKE_C_FLAGS_DEBUG="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_DEBUG} ${EXCEPTION_FLAGS}" \
        -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
        -D BUILD_SHARED_LIBS=ON \
        -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
        ${EXTRA_DEFS} \
        ${CMAKE_WIN_SDK} \
        -DBUILD_WITH_STATIC_CRT=OFF 
     cmake --build . --target install --config Debug
     cmake .. ${DEFS} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}" \
        -DCMAKE_INSTALL_PREFIX=Release \
        -DCMAKE_BUILD_TYPE="Release" \
        -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
        -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
        -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
        -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
        -D BUILD_SHARED_LIBS=ON \
        ${EXTRA_DEFS} \
        -DBUILD_WITH_STATIC_CRT=OFF \
        ${CMAKE_WIN_SDK}
    cmake --build . --target install --config Release
    cd ..    

  elif [ "$TYPE" == "android" ]; then
    export ANDROID_NDK=${NDK_ROOT}
    if [ "$ABI" = "armeabi-v7a" ] || [ "$ABI" = "armeabi" ]; then
      local BUILD_FOLDER="build_android_arm"
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

    # NDK_ROOT=${NDK_OLD_ROOT}

    source ../../android_configure.sh $ABI cmake

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

    if [[ ${ABI} == "arm64-v8a" || "${ABI}" == "armeabi-v7a" ]]; then
      EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=OFF -DENABLE_SSE=OFF -DENABLE_SSE2=OFF -DENABLE_SSE3=OFF -DENABLE_SSE41=OFF -DENABLE_SSE42=OFF -DENABLE_SSSE3=OFF"
    else 
      EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DENABLE_SSE=ON -DENABLE_SSE2=ON -DENABLE_SSE3=ON -DENABLE_SSE41=ON -DENABLE_SSE42=ON -DENABLE_SSSE3=ON"
    fi

    cmake  \
      -DANDROID_TOOLCHAIN=clang++ \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake  \
      -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
      -DCMAKE_CXX_FLAGS="" \
      -DCMAKE_C_FLAGS="" \
      -DCMAKE_SYSROOT=$SYSROOT \
      -DANDROID_NDK=$NDK_ROOT \
      -DANDROID_ABI=$ABI \
      -DCMAKE_ANDROID_ARCH_ABI=$ABI \
      -DANDROID_STL=c++_shared \
      -DCMAKE_C_STANDARD=17 \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_STANDARD_REQUIRED=ON \
      -DCMAKE_CXX_EXTENSIONS=OFF \
      -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
      -DANDROID_ABI=${ABI} \
      -DBUILD_ANDROID_PROJECTS=OFF \
      -DBUILD_ANDROID_EXAMPLES=OFF \
      -DBUILD_opencv_objdetect=ON \
      -DBUILD_opencv_video=OFF \
      -DBUILD_opencv_videoio=OFF \
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
      -DHAVE_opencv_androidcamera=OFF \
      -DWITH_CAROTENE=OFF \
      -DWITH_CPUFEATURES=OFF \
      -DWITH_TIFF=OFF \
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
      ${EXTRA_DEFS} \
      -DBUILD_TESTS=OFF \
      -DANDROID_NDK=${NDK_ROOT} \
      -DCMAKE_BUILD_TYPE=Release \
      -DANDROID_STL=c++_shared \
      -DANDROID_PLATFORM=$ANDROID_PLATFORM \
      -DBUILD_PERF_TESTS=OFF ..
    make -j${PARALLEL_MAKE}
    make install

  elif [ "$TYPE" == "emscripten" ]; then

    # check if emsdk is sourced and EMSDK is set
    if [ -z ${EMSDK+x} ]; then
        # if not, try docker path
        if [ -f /emsdk/emsdk_env.sh ]; then
            source /emsdk/emsdk_env.sh
	    else
            echo "no EMSDK found, please install from https://emscripten.org"
            echo "and follow instructions to activate it in your shell"
            exit 1
        fi
    fi

    # cd ${BUILD_DIR}/${1}
    
    # fix a bug with newer emscripten not recognizing index and string error because python files opened in binary

    mkdir -p build_${TYPE}
    cd build_${TYPE}
    
    emcmake cmake .. \
      -B build \
      -DCMAKE_BUILD_TYPE="Release" \
      -DCMAKE_INSTALL_LIBDIR="lib" \
      -DCMAKE_C_STANDARD=17 \
      -DCMAKE_CXX_STANDARD=17 \
      -DCPU_BASELINE='' \
      -DCPU_DISPATCH='' \
      -DCV_TRACE=OFF \
      -DCMAKE_C_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128 ${FLAG_RELEASE}" \
      -DCMAKE_CXX_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128 ${FLAG_RELEASE}" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
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
      -DBUILD_opencv_shape=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_superres=OFF \
      -DBUILD_opencv_stitching=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_python3=OFF \
      -DBUILD_opencv_objdetect=ON \
      -DBUILD_opencv_video=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_features2d=ON \
      -DBUILD_opencv_flann=ON \
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
      -DENABLE_SSE=OFF \
      -DENABLE_SSE2=OFF \
      -DENABLE_SSE3=OFF \
      -DENABLE_SSE41=OFF \
      -DENABLE_SSE42=OFF \
      -DENABLE_SSSE3=OFF \
      -DENABLE_AVX=OFF \
      -DWITH_TIFF=OFF \
      -DWITH_OPENEXR=OFF \
      -DWITH_OPENGL=OFF \
      -DWITH_OPENVX=OFF \
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
      -DWITH_GSTREAMER=OFF \
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
      -DBUILD_ZLIB=ON \
      -DWITH_WEBP=OFF \
      -DWITH_VTK=OFF \
      -DWITH_PVAPI=OFF \
      -DWITH_EIGEN=OFF \
      -DWITH_GTK=OFF \
      -DWITH_GTK_2_X=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DWITH_OPENCLAMDFFT=OFF \
      -DWASM=ON \
      -DBUILD_TESTS=OFF \
      -DCV_ENABLE_INTRINSICS=OFF \
      -DBUILD_WASM_INTRIN_TESTS=OFF \
      -DBUILD_PERF_TESTS=OFF \
      -DBUILD_SHARED_LIBS=OFF \
      -DCMAKE_INSTALL_PREFIX=Release \
      -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
      -DCMAKE_INSTALL_INCLUDEDIR=include
    cmake --build build --target install --config Release
  fi

}


# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

  # prepare headers directory if needed
  mkdir -p $1/include

  # prepare libs directory if needed
  mkdir -p $1/lib/$TYPE

  if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

    mkdir -p $1/lib/$TYPE/$PLATFORM

    cp -v "build_${TYPE}_${PLATFORM}/Release/lib/opencv4/3rdparty/"*.a $1/lib/$TYPE/$PLATFORM/
    cp -v "build_${TYPE}_${PLATFORM}/Release/lib/"*.a $1/lib/$TYPE/$PLATFORM

    cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/opencv4" $1/include/

  elif [ "$TYPE" == "vs" ] ; then
     
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/etc

    cp -Rv "build_${TYPE}_${ARCH}/Release/include/opencv2" $1/include/
    mkdir -p $1/lib/$TYPE/$PLATFORM/

    mkdir -p $1/lib/$TYPE/$PLATFORM/Debug
    mkdir -p $1/lib/$TYPE/$PLATFORM/Release

    mkdir -p $1/bin//$PLATFORM/Debug
    mkdir -p $1/bin/$PLATFORM/Release

    OUTPUT_FOLDER=${BUILD_PLATFORM}

    cp -v "build_${TYPE}_${ARCH}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Release
    cp -v "build_${TYPE}_${ARCH}/Debug/${OUTPUT_FOLDER}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

    cp -v "build_${TYPE}_${ARCH}/Release/${OUTPUT_FOLDER}/vc${VS_VER}/bin/"*.dll $1/bin/$PLATFORM/Release
    cp -v "build_${TYPE}_${ARCH}/Debug/${OUTPUT_FOLDER}/vc${VS_VER}/bin/"*.dll $1/bin/$PLATFORM/Debug

    cp -v "build_${TYPE}_${ARCH}/3rdparty/lib/Release/"*.lib $1/lib/$TYPE/$PLATFORM/Release
    cp -v "build_${TYPE}_${ARCH}/3rdparty/lib/Debug/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

    cp -Rv "build_${TYPE}_${ARCH}/Release/etc/" $1/etc

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

    mkdir -p $1/lib/$TYPE/$ABI/
    cp -r $BUILD_FOLDER/install/sdk/native/staticlibs/$ABI/*.a $1/lib/$TYPE/$ABI/
    cp -r $BUILD_FOLDER/install/sdk/native/3rdparty/libs/$ABI/*.a $1/lib/$TYPE/$ABI/

  elif [ "$TYPE" == "emscripten" ]; then
    mkdir -p $1/include/opencv2
    cp -Rv "build_${TYPE}/Release/include/" $1/include/
    cp -R include/opencv2 $1/include/
    cp -R modules/*/include/opencv2/* $1/include/opencv2/
    cp -v build_${TYPE}/Release/lib/*.a $1/lib/$TYPE/
    cp -v build_${TYPE}/Release/lib/opencv4/3rdparty/*.a $1/lib/$TYPE/
  fi

  # copy license file
  if [ -d "$1/license" ]; then
    rm -rf $1/license
  fi
  mkdir -p $1/license
  cp -v LICENSE $1/license/

}

# executed inside the lib src dir
function clean() {
  if [ "$TYPE" == "vs" ] ; then
    if [ -d "build_${TYPE}_${ARCH}" ]; then
      rm -r build_${TYPE}_${ARCH}     
    fi
  elif [ "$TYPE" == "android" ] ; then
    if [ -d "build_${TYPE}_${ABI}" ]; then
    rm -r build_${TYPE}_${ABI}     
    fi
  elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
    if [ -d "build_${TYPE}_${PLATFORM}" ]; then
      rm -r build_${TYPE}_${PLATFORM}     
    fi
  fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "opencv" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "opencv" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
