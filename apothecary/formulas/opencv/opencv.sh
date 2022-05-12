#!/usr/bin/env bash
#
# OpenCV
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "ios" "tvos" "vs" "android" "emscripten" )

# define the version
VER=4.5.5

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
  wget --quiet https://github.com/opencv/opencv/archive/$VER.tar.gz -O opencv-$VER.tar.gz
  tar -xf opencv-$VER.tar.gz
  mv opencv-$VER $1
  rm opencv*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
  : # noop
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
    unset TMP
    unset TEMP

    rm -f CMakeCache.txt
    #LIB_FOLDER="$BUILD_DIR/opencv/build/$TYPE"
    mkdir -p $LIB_FOLDER
    LOG="$LIB_FOLDER/opencv2-${VER}.log"
    echo "Logging to $LOG"
    echo "Log:" >> "${LOG}" 2>&1
    set +e

    python3 -m ensurepip --upgrade
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    
    python3 get-pip.py
    python3 -m pip help
    python3 -m pip install --upgrade pip
    python3 -m pip install numpy

    # python3 -VV
    # python3 -m pip install numpy


    export PYTHON_VERSION_STRING=3.9.10
    export PYTHON_EXECUTABLE=C:/hostedtoolcache/windows/Python/3.9.10/x64/python.exe



    if [ $ARCH == 32 ] ; then
      mkdir -p build_vs_32
      cd build_vs_32
      echo "Visual Studio $VS_VER -A Win32 "

      cmake .. -G "Visual Studio $VS_VER" -A Win32 \
      -DBUILD_PNG=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
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
      -DHAVE_opencv_python2=OFF \
      -DHAVE_opencv_python3=OFF \
      -DPYTHON_VERSION_STRING=$PYTHON_VERSION_STRING \
      -DPYTHON_DEFAULT_EXECUTABLE=$PYTHON_EXECUTABLE \
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
      -DBUILD_SHARED_LIBS=OFF \
      -DWITH_PNG=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_PVAPI=OFF \
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
      -DBUILD_TESTS=OFF  
      # | tee ${LOG}
      echo "CMAKE Successful"
      echo "--------------------"
      echo "Running make clean"

      make clean 2>&1 | tee -a ${LOG}
      echo "Make Clean Successful"
      vs-build "OpenCV.sln" Build "Release|Win32"
      vs-build "OpenCV.sln" Build "Debug|Win32"
    elif [ $ARCH == 64 ] ; then
      mkdir -p build_vs_64
      cd build_vs_64
      echo "Visual Studio $VS_VER -A x64 "
      cmake .. -G "Visual Studio $VS_VER" -A x64 \
      -DBUILD_PNG=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
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
      -DHAVE_opencv_python2=OFF \
      -DPYTHON_VERSION_STRING=$PYTHON_VERSION_STRING \
      -DPYTHON_DEFAULT_EXECUTABLE=$PYTHON_EXECUTABLE \
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
      -DBUILD_SHARED_LIBS=OFF \
      -DWITH_PNG=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_PVAPI=OFF\
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
      -DBUILD_TESTS=OFF
       # | tee ${LOG}
      vs-build "OpenCV.sln" Build "Release|x64"
      vs-build "OpenCV.sln" Build "Debug|x64"
    elif [ $ARCH == "ARM64" ] ; then
      mkdir -p build_vs_arm64
      cd build_vs_arm64
      echo "Visual Studio $VS_VER -A ARM64 "

      cmake .. -G "Visual Studio $VS_VER" -A ARM64 \
      -DBUILD_PNG=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
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
      -DHAVE_opencv_python2=OFF \
      -DPYTHON_VERSION_STRING=$PYTHON_VERSION_STRING \
      -DPYTHON_DEFAULT_EXECUTABLE=$PYTHON_EXECUTABLE \
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
      -DBUILD_SHARED_LIBS=OFF \
      -DWITH_PNG=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_PVAPI=OFF\
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
      -DBUILD_TESTS=OFF
       # | tee ${LOG}
      vs-build "OpenCV.sln" Build "Release|ARM64"
      vs-build "OpenCV.sln" Build "Debug|ARM64"
  elif [ $ARCH == "ARM" ] ; then
      mkdir -p build_vs_arm
      cd build_vs_arm
      echo "Visual Studio $VS_VER -A ARM "
      cmake .. -G "Visual Studio $VS_VER" -A ARM \
      -DBUILD_PNG=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ " \
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
      -DHAVE_opencv_python2=OFF \
      -DPYTHON_VERSION_STRING=$PYTHON_VERSION_STRING \
      -DPYTHON_DEFAULT_EXECUTABLE=$PYTHON_EXECUTABLE \
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
      -DBUILD_SHARED_LIBS=OFF \
      -DWITH_PNG=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_PVAPI=OFF\
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
      -DBUILD_TESTS=OFF
       # | tee ${LOG}
      vs-build "OpenCV.sln" Build "Release|ARM"
      vs-build "OpenCV.sln" Build "Debug|ARM"
    fi
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

      BITCODE=""
      if [[ "$TYPE" == "tvos" ]] || [[ "${IOS_ARCH}" == "arm64" ]]; then
          BITCODE=-fembed-bitcode;
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
    #source /emsdk/emsdk_env.sh

    cd ${BUILD_DIR}/${1}
    
    # fix a bug with newer emscripten not recognizing index and string error because python files opened in binary
    # these can be removed when we move to latest opencv 
    #sed -i "s|element(index|element(emscripten::index|" modules/js/src/core_bindings.cpp
    #sed -i "s|open(opencvjs, 'r+b')|open(opencvjs, 'r+')|" modules/js/src/make_umd.py
    #sed -i "s|open(cvjs, 'w+b')|open(cvjs, 'w+')|" modules/js/src/make_umd.py

    mkdir -p build_${TYPE}
    cd build_${TYPE}
    
    emcmake cmake .. -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/${1}/build_$TYPE/install" \
      -DCMAKE_BUILD_TYPE="Release" \
      -DBUILD_opencv_js=ON \
      -DCPU_BASELINE='' \
      -DCPU_DISPATCH='' \
      -DCV_TRACE=OFF \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -O3 -Wno-implicit-function-declaration -msse2 -msimd128 -experimental-wasm-simd" \
      -DCMAKE_CXX_FLAGS=" -fvisibility-inlines-hidden -stdlib=libc++ -O3 -Wno-implicit-function-declaration -msse2 -msimd128 -experimental-wasm-simd" \
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
      -DBUILD_opencv_python=OFF \
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
      -DBUILD_TESTS=OFF \
      -DBUILD_PERF_TESTS=OFF
    make 
    make install
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
    if [ $ARCH == 32 ] ; then
      DEPLOY_PATH="$1/lib/$TYPE/Win32"
    elif [ $ARCH == 64 ] ; then
      DEPLOY_PATH="$1/lib/$TYPE/x64"
    fi
    mkdir -p "$DEPLOY_PATH/Release"
    mkdir -p "$DEPLOY_PATH/Debug"
    # now make sure the target directories are clean.
    rm -Rf "${DEPLOY_PATH}/Release/*"
    rm -Rf "${DEPLOY_PATH}/Debug/*"
    #copy the cv libs
    cp -v build_vs_${ARCH}/lib/Release/*.lib "${DEPLOY_PATH}/Release"
    cp -v build_vs_${ARCH}/lib/Debug/*.lib "${DEPLOY_PATH}/Debug"
    #copy the zlib
    cp -v build_vs_${ARCH}/3rdparty/lib/Release/*.lib "${DEPLOY_PATH}/Release"
    cp -v build_vs_${ARCH}/3rdparty/lib/Debug/*.lib "${DEPLOY_PATH}/Debug"

    cp -R include/opencv2 $1/include/
    cp -R build_vs_${ARCH}/opencv2/* $1/include/opencv2/
    cp -R modules/*/include/opencv2/* $1/include/opencv2/

    #copy the ippicv includes and lib
    IPPICV_SRC=build_vs_${ARCH}/3rdparty/ippicv/ippicv_win/icv
    IPPICV_DST=$1/../ippicv
    if [ $ARCH == 32 ] ; then
      IPPICV_PLATFORM="ia32"
      IPPICV_DEPLOY="${IPPICV_DST}/lib/$TYPE/Win32"
    elif [ $ARCH == 64 ] ; then
      IPPICV_PLATFORM="intel64"
      IPPICV_DEPLOY="${IPPICV_DST}/lib/$TYPE/x64"
    fi
    mkdir -p ${IPPICV_DST}/include
    cp -R ${IPPICV_SRC}/include/ ${IPPICV_DST}/
    mkdir -p ${IPPICV_DEPLOY}
    cp -v ${IPPICV_SRC}/lib/${IPPICV_PLATFORM}/*.lib "${IPPICV_DEPLOY}"

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
    cp -r build_emscripten/install/include/* $1/include/
    cp -R include/opencv2 $1/include/
    cp -R modules/*/include/opencv2/* $1/include/opencv2/
    cp -r build_emscripten/install/lib/*.a $1/lib/$TYPE/
    cp -r build_emscripten/install/lib/opencv4/3rdparty/*.a $1/lib/$TYPE/
  fi

  # copy license file
  rm -rf $1/license # remove any older files if exists
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
