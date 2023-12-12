#!/usr/bin/env bash
#
# OpenCV
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "ios" "tvos" "vs" "android" "emscripten" )

# define the version

VER=4.8.1


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
  rm -f CMakeCache.txt

  LIB_FOLDER="$BUILD_DIR/opencv/build/$TYPE/"
  mkdir -p $LIB_FOLDER

  if [ "$TYPE" == "osx" ] ; then
    LOG="$LIB_FOLDER/opencv2-${VER}.log"
    
    # fix for arm64 builds for 4.0.1 which the ittnotify_config.h doesn't detect correctly.
    # this can prob be removed in later opencv versions
    sed -i'' -e  "s|return __TBB_machine_fetchadd4(ptr, 1) + 1L;|return __atomic_fetch_add(ptr, 1L, __ATOMIC_SEQ_CST) + 1L;|" 3rdparty/ittnotify/src/ittnotify/ittnotify_config.h
    
    echo "Logging to $LOG"
    cd build
    rm -f CMakeCache.txt
    echo "Log:" >> "${LOG}" 2>&1
    set +e
    cmake .. -DCMAKE_INSTALL_PREFIX=$LIB_FOLDER \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER} \
      -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" \
      -DENABLE_FAST_MATH=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -std=c++17 -O3 -fPIC -arch arm64 -arch x86_64 -Wno-implicit-function-declaration -mmacosx-version-min=${OSX_MIN_SDK_VER}" \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -O3 -fPIC -arch arm64 -arch x86_64 -Wno-implicit-function-declaration -mmacosx-version-min=${OSX_MIN_SDK_VER}" \
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
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_imgcodecs=OFF \
      -DBUILD_opencv_stitching=OFF \
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
      -DWITH_OPENEXR=OFF \
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
      -DBUILD_PERF_TESTS=OFF 2>&1 | tee -a ${LOG}
    echo "CMAKE Successful"
    echo "--------------------"
    echo "Running make clean"

    make clean 2>&1 | tee -a ${LOG}
    echo "Make Clean Successful"

    echo "--------------------"
    echo "Running make"
    make -j${PARALLEL_MAKE} 2>&1 | tee -a ${LOG}
    echo "Make  Successful"

    echo "--------------------"
    echo "Running make install"
    make install 2>&1 | tee -a ${LOG}
    echo "Make install Successful"

    echo "--------------------"
    # we don't do this anymore as it results in duplicate symbol issues
    # echo "Joining all libs in one"
    # outputlist="$LIB_FOLDER/lib/lib*.a $LIB_FOLDER/lib/opencv4/3rdparty/*.a"
    # libtool -static $outputlist -o "$LIB_FOLDER/lib/opencv.a" 2>&1 | tee -a ${LOG}
    # echo "Joining all libs in one Successful"

  elif [ "$TYPE" == "vs" ] ; then
    echoInfo "building $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN - "${PLATFORM}""
    echoInfo "--------------------"
    GENERATOR_NAME="Visual Studio ${VS_VER_GEN}" 
    mkdir -p "build_${TYPE}_${ARCH}"
    cd "build_${TYPE}_${ARCH}"
    DEFS="
        -DCMAKE_C_STANDARD=17 \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=install \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include\
        -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
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
        -DHAVE_opencv_python3=OFF \
        -DHAVE_opencv_python=OFF \
        -DHAVE_opencv_python2=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_opencv_videoio=OFF \
        -DBUILD_opencv_videostab=OFF \
        -DBUILD_opencv_highgui=OFF \
        -DBUILD_opencv_imgcodecs=OFF \
        -DBUILD_opencv_stitching=OFF \
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
     
  
    cmake .. ${DEFS} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}" \
        -DCMAKE_INSTALL_PREFIX=Debug \
        -D CMAKE_VERBOSE_MAKEFILE=OFF \
        -D BUILD_SHARED_LIBS=ON \
        ${CMAKE_WIN_SDK}

    cmake --build . --target install --config Debug


     cmake .. ${DEFS} \
        -A "${PLATFORM}" \
        -G "${GENERATOR_NAME}" \
        -DCMAKE_INSTALL_PREFIX=Release \
        -D CMAKE_VERBOSE_MAKEFILE=OFF \
        -D BUILD_SHARED_LIBS=ON \
        ${CMAKE_WIN_SDK}
        

    cmake --build . --target install --config Release

    # cmake -DCMAKE_BUILD_TYPE=Release --build . --config Release 

    # cmake --build build --target install --config Release

    cd ..    
    
  elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
    local IOS_ARCHS
    if [[ "${TYPE}" == "tvos" ]]; then
        IOS_ARCHS="x86_64 arm64"
    elif [[ "$TYPE" == "ios" ]]; then
        IOS_ARCHS="x86_64 armv7 arm64" #armv7s
    fi
    CURRENTPATH=`pwd`

      # loop through architectures! yay for loops!
    for IOS_ARCH in ${IOS_ARCHS}
    do
      source ${APOTHECARY_DIR}/ios_configure.sh $TYPE $IOS_ARCH

      cd build

      if [[ "$TYPE" == "tvos" ]] || [[ "${IOS_ARCH}" == "arm64" ]]; then
          MIN_IOS_VERSION=13.0
      fi

      WITH_ITT=ON
      if [[ "${IOS_ARCH}" == "arm64" ]]; then
        WITH_ITT=OFF
      fi

      cmake .. -DCMAKE_INSTALL_PREFIX="$CURRENTPATH/build/$TYPE/$IOS_ARCH" \
      -DIOS=1 \
      -DAPPLE=1 \
      -DUNIX=1 \
      -DCMAKE_CXX_COMPILER=$CXX \
      -DCMAKE_CC_COMPILER=$CC \
      -DIPHONESIMULATOR=$ISSIM \
      -DCMAKE_CXX_COMPILER_WORKS="TRUE" \
      -DCMAKE_C_COMPILER_WORKS="TRUE" \
      -DSDKVER="${SDKVERSION}" \
      -DCMAKE_IOS_DEVELOPER_ROOT="${CROSS_TOP}" \
      -DDEVROOT="${CROSS_TOP}" \
      -DSDKROOT="${CROSS_SDK}" \
      -DCMAKE_OSX_SYSROOT="${SYSROOT}" \
      -DCMAKE_OSX_ARCHITECTURES="${IOS_ARCH}" \
      -DCMAKE_XCODE_EFFECTIVE_PLATFORMS="-$PLATFORM" \
      -DGLFW_BUILD_UNIVERSAL=ON \
      -DENABLE_FAST_MATH=OFF \
      -DCMAKE_CXX_FLAGS="-stdlib=libc++ -fvisibility=hidden $BITCODE -fPIC -Wno-implicit-function-declaration -isysroot ${SYSROOT} -DNDEBUG -Os $MIN_TYPE$MIN_IOS_VERSION" \
      -DCMAKE_C_FLAGS="-stdlib=libc++ -fvisibility=hidden $BITCODE -fPIC -Wno-implicit-function-declaration -isysroot ${SYSROOT} -DNDEBUG -Os $MIN_TYPE$MIN_IOS_VERSION"  \
      -DCMAKE_BUILD_TYPE="Release" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_TESTS=OFF \
      -DBUILD_PERF_TESTS=OFF \
      -DBUILD_CUDA_STUBS=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_videostab=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_imgcodecs=OFF \
      -DBUILD_opencv_gapi=OFF \
      -DBUILD_opencv_ml=OFF \
      -DBUILD_opencv_shape=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_superres=OFF \
      -DBUILD_opencv_stitching=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_python3=OFF \
      -DENABLE_SSE=OFF \
      -DENABLE_SSE2=OFF \
      -DENABLE_SSE3=OFF \
      -DENABLE_SSE41=OFF \
      -DENABLE_SSE42=OFF \
      -DENABLE_SSSE3=OFF \
      -DENABLE_AVX=OFF \
      -DWITH_TIFF=OFF \
      -DWITH_OPENEXR=OFF \
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
      -DWITH_ITT=${WITH_ITT} \
      -DBUILD_PERF_TESTS=OFF


      echo "--------------------"
      echo "Running make clean for ${IOS_ARCH}"
      make clean

      echo "--------------------"
      echo "Running make for ${IOS_ARCH}"
      make -j${PARALLEL_MAKE}

      echo "--------------------"
      echo "Running make install for ${IOS_ARCH}"
      make install

      rm -f CMakeCache.txt
      cd ..
    done

    mkdir -p lib/$TYPE
    echo "--------------------"
    echo "Creating Fat Libs"
    cd "build/$TYPE"
    # link into universal lib, strip "lib" from filename
    local lib
    rm -rf arm64/lib/pkgconfig

    for lib in arm64/lib/*.a; do
      baselib=$(basename $lib)
      local renamedLib=$(echo $baselib | sed 's|lib||')
      if [ ! -e $renamedLib ] ; then
        echo "renamed $renamedLib";
        if [[ "${TYPE}" == "tvos" ]] ; then
          lipo -c arm64/lib/$baselib x86_64/lib/$baselib -o "$CURRENTPATH/lib/$TYPE/$renamedLib"
        elif [[ "$TYPE" == "ios" ]]; then
          lipo -c armv7/lib/$baselib arm64/lib/$baselib x86_64/lib/$baselib -o "$CURRENTPATH/lib/$TYPE/$renamedLib"
        fi
      fi
    done

    cd ../../
    echo "--------------------"
    echo "Copying includes"
    cp -R "build/$TYPE/x86_64/include/" "lib/include/"

    echo "--------------------"
    echo "Stripping any lingering symbols"

    cd lib/$TYPE
    for TOBESTRIPPED in $( ls -1) ; do
      strip -x $TOBESTRIPPED
    done

    cd ../../

  # end if iOS

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

    cmake  \
      -DANDROID_TOOLCHAIN=clang++ \
      -DCMAKE_TOOLCHAIN_FILE=${NDK_ROOT}/build/cmake/android.toolchain.cmake  \
      -DCMAKE_CXX_COMPILER_RANLIB=${RANLIB} \
      -DCMAKE_CXX_FLAGS="" \
      -DCMAKE_C_FLAGS="" \
      -DCMAKE_SYSROOT=$SYSROOT \
      -DANDROID_NDK=$NDK_ROOT \
      -DANDROID_ABI=$ABI \
      -DANDROID_STL=c++_shared \
      -DCMAKE_C_STANDARD=17 \
      -DCMAKE_CXX_STANDARD=17 \
      -DCMAKE_CXX_STANDARD_REQUIRED=ON \
      -DCMAKE_CXX_EXTENSIONS=OFF \
      -DANDROID_PLATFORM=${ANDROID_PLATFORM} \
      -DANDROID_ABI=${ABI} \
      -DBUILD_ANDROID_PROJECTS=OFF \
      -DBUILD_ANDROID_EXAMPLES=OFF \
      -DBUILD_opencv_objdetect=OFF \
      -DBUILD_opencv_video=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_features2d=OFF \
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
      -DBUILD_TESTS=OFF \
      -DANDROID_NDK=${NDK_ROOT} \
      -DCMAKE_BUILD_TYPE=Release \
      -DANDROID_ABI=$ABI \
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
      -DCMAKE_C_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128" \
      -DCMAKE_CXX_FLAGS="-pthread -I/${EMSDK}/upstream/emscripten/system/lib/libcxxabi/include/ -msimd128" \
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
      -DBUILD_opencv_js=ON \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_videostab=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_imgcodecs=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_gapi=OFF \
      -DBUILD_opencv_ml=OFF \
      -DBUILD_opencv_shape=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_superres=OFF \
      -DBUILD_opencv_stitching=OFF \
      -DBUILD_opencv_python2=OFF \
      -DBUILD_opencv_python3=OFF \
      -DBUILD_opencv_objdetect=OFF \
      -DBUILD_opencv_video=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_features2d=OFF \
      -DBUILD_opencv_flann=OFF \
      -DBUILD_opencv_photo=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_shape=OFF \
      -DBUILD_opencv_stitching=OFF \
      -DBUILD_opencv_superres=OFF \
      -DBUILD_opencv_ts=OFF \
      -DBUILD_opencv_videostab=OFF \
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
    # make 
    # make install
  fi

}


# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

  # prepare headers directory if needed
  mkdir -p $1/include

  # prepare libs directory if needed
  mkdir -p $1/lib/$TYPE

  if [ "$TYPE" == "osx" ] ; then
    # Standard *nix style copy.
    # copy headers

    LIB_FOLDER="$BUILD_DIR/opencv/build/$TYPE/"

    cp -R $LIB_FOLDER/include/ $1/include/
    cp -R include/opencv2 $1/include/
    cp -R modules/*/include/opencv2/* $1/include/opencv2/

    # copy lib
    cp -R $LIB_FOLDER/lib/lib*.a $1/lib/$TYPE/
    cp -R $LIB_FOLDER/lib/opencv4/3rdparty/*.a $1/lib/$TYPE/

  elif [ "$TYPE" == "vs" ] ; then
    
    mkdir -p $1/include    
    mkdir -p $1/lib/$TYPE
    mkdir -p $1/etc



    # cp -Rv "include/" $1/
    cp -R "build_${TYPE}_${ARCH}/Release/include/" $1/include/
    mkdir -p $1/lib/$TYPE/$PLATFORM/

    mkdir -p $1/lib/$TYPE/$PLATFORM/Debug
    mkdir -p $1/lib/$TYPE/$PLATFORM/Release

    cp -v "build_${TYPE}_${ARCH}/Release/${BUILD_PLATFORM}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Release
    cp -v "build_${TYPE}_${ARCH}/Debug/${BUILD_PLATFORM}/vc${VS_VER}/lib/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

    cp -v "build_${TYPE}_${ARCH}/3rdparty/lib/Release/"*.lib $1/lib/$TYPE/$PLATFORM/Release
    cp -v "build_${TYPE}_${ARCH}/3rdparty/lib/Debug/"*.lib $1/lib/$TYPE/$PLATFORM/Debug

    cp -Rv "build_${TYPE}_${ARCH}/Release/etc/" $1/etc




   
  elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
    # Standard *nix style copy.
    # copy headers

    LIB_FOLDER="$BUILD_ROOT_DIR/$TYPE/FAT/opencv"

    cp -Rv lib/include/ $1/include/
    cp -R include/opencv2 $1/include/
    cp -R modules/*/include/opencv2/* $1/include/opencv2/
    mkdir -p $1/lib/$TYPE
    cp -v lib/$TYPE/*.a $1/lib/$TYPE
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
  if [ "$TYPE" == "osx" ] ; then
    make clean;
  elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
    make clean;
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
