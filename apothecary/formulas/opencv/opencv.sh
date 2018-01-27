#!/usr/bin/env bash
#
# OpenCV
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system
 
FORMULA_TYPES=( "osx" "ios" "tvos" "vs" "android" "emscripten" )
 
# define the version 
VER=3.1.0
 
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
    echo "Logging to $LOG"
    cd build
    rm -f CMakeCache.txt
    echo "Log:" >> "${LOG}" 2>&1
    set +e
    cmake .. -DCMAKE_INSTALL_PREFIX=$LIB_FOLDER \
      -DCMAKE_OSX_DEPLOYMENT_TARGET=10.7 \
      -DENABLE_FAST_MATH=OFF \
      -DCMAKE_CXX_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -O3 -fPIC -arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}" \
      -DCMAKE_C_FLAGS="-fvisibility-inlines-hidden -stdlib=libc++ -O3 -fPIC -arch i386 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}" \
      -DCMAKE_BUILD_TYPE="Release" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_JPEG=OFF \
      -DBUILD_PNG=OFF \
      -DWITH_1394=OFF \
      -DWITH_CARBON=OFF \
      -DWITH_JPEG=OFF \
      -DWITH_PNG=OFF \
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
    echo "Joining all libs in one"
    outputlist="lib/lib*.a"
    libtool -static $outputlist -o "$LIB_FOLDER/lib/opencv.a" 2>&1 | tee -a ${LOG}
    echo "Joining all libs in one Successful"

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
    
    if [ $ARCH == 32 ] ; then
      mkdir -p build_vs_32
      cd build_vs_32
      cmake .. -G "Visual Studio $VS_VER"\
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
      -DBUILD_opencv_apps=OFF \
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
      -DWITH_PVAPI=OFF  | tee ${LOG} 
      vs-build "OpenCV.sln" Build "Release|Win32"
      vs-build "OpenCV.sln" Build "Debug|Win32"
    elif [ $ARCH == 64 ] ; then
      mkdir -p build_vs_64
      cd build_vs_64
      cmake .. -G "Visual Studio $VS_VER Win64" \
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
      -DBUILD_opencv_apps=OFF \
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
      -DWITH_PVAPI=OFF  | tee ${LOG} 
      vs-build "OpenCV.sln" Build "Release|x64"
      vs-build "OpenCV.sln" Build "Debug|x64"
    fi
    
  elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
    local IOS_ARCHS
    if [[ "${TYPE}" == "tvos" ]]; then
        IOS_ARCHS="x86_64 arm64"
    elif [[ "$TYPE" == "ios" ]]; then
        IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
    fi
    CURRENTPATH=`pwd`

      # loop through architectures! yay for loops!
    for IOS_ARCH in ${IOS_ARCHS}
    do
      source ${APOTHECARY_DIR}/ios_configure.sh $TYPE $IOS_ARCH

      cd build

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
      -DCMAKE_CXX_FLAGS="-stdlib=libc++ -fvisibility=hidden $BITCODE -fPIC -isysroot ${SYSROOT} -DNDEBUG -Os $MIN_TYPE$MIN_IOS_VERSION" \
      -DCMAKE_C_FLAGS="-stdlib=libc++ -fvisibility=hidden $BITCODE -fPIC -isysroot ${SYSROOT} -DNDEBUG -Os $MIN_TYPE$MIN_IOS_VERSION"  \
      -DCMAKE_BUILD_TYPE="Release" \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_JPEG=OFF \
      -DBUILD_PNG=OFF \
      -DWITH_1394=OFF \
      -DWITH_JPEG=OFF \
      -DWITH_PNG=OFF \
      -DWITH_CARBON=OFF \
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
      -DWITH_EIGEN=OFF \
      -DWITH_OPENEXR=OFF \
      -DBUILD_OPENEXR=OFF \
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

    for lib in $( ls -1 arm64/lib) ; do
      local renamedLib=$(echo $lib | sed 's|lib||')
      if [ ! -e $renamedLib ] ; then
        echo "renamed";
        if [[ "${TYPE}" == "tvos" ]] ; then
          lipo -c arm64/lib/$lib x86_64/lib/$lib -o "$CURRENTPATH/lib/$TYPE/$renamedLib"
        elif [[ "$TYPE" == "ios" ]]; then
          lipo -c armv7/lib/$lib arm64/lib/$lib i386/lib/$lib x86_64/lib/$lib -o "$CURRENTPATH/lib/$TYPE/$renamedLib"
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
    elif [ "$ABI" = "x86" ]; then
      local BUILD_FOLDER="build_android_x86"
      local BUILD_SCRIPT="cmake_android_x86.sh"
    fi
    
    source ../../android_configure.sh $ABI

    cd platforms
    rm -rf $BUILD_FOLDER

    echo ${ANDROID_NDK}
    pwd
    scripts/${BUILD_SCRIPT} \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_python=OFF \
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
      -DANDROID_NDK=$NDK_ROOT \
      -DCMAKE_BUILD_TYPE=Release \
      -DANDROID_ABI=$ABI \
      -DANDROID_STL=c++_static \
      -DANDROID_NATIVE_API_LEVEL=$ANDROID_PLATFORM \
      -DANDROID_FORCE_ARM_BUILD=TRUE \
      -DCMAKE_TOOLCHAIN_FILE=$ANDROID_CMAKE_TOOLCHAIN \
      -DBUILD_PERF_TESTS=OFF
    cd $BUILD_FOLDER
    make -j${PARALLEL_MAKE}
    make install

  elif [ "$TYPE" == "emscripten" ]; then
    if [ -z "${EMSCRIPTEN+x}" ]; then
      echo "emscripten is not set.  sourcing emsdk_env.sh"
      source ~/emscripten-sdk/emsdk_env.sh
    fi
  
    cd ${BUILD_DIR}/${1}
    mkdir -p build_${TYPE}
    cd build_${TYPE}
    emcmake cmake .. -DCMAKE_INSTALL_PREFIX="${BUILD_DIR}/${1}/build_$TYPE/install" \
      -DCMAKE_BUILD_TYPE="Release" \
      -DCMAKE_C_FLAGS=-I${EMSCRIPTEN}/system/lib/libcxxabi/include/ \
      -DCMAKE_CXX_FLAGS=-I${EMSCRIPTEN}/system/lib/libcxxabi/include/ \
      -DBUILD_SHARED_LIBS=OFF \
      -DBUILD_DOCS=OFF \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_FAT_JAVA_LIB=OFF \
      -DBUILD_JASPER=OFF \
      -DBUILD_PACKAGE=OFF \
      -DBUILD_CUDA_STUBS=OFF \
      -DBUILD_opencv_java=OFF \
      -DBUILD_opencv_python=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_JPEG=OFF \
      -DBUILD_PNG=OFF \
      -DBUILD_opencv_apps=OFF \
      -DBUILD_opencv_videoio=OFF \
      -DBUILD_opencv_highgui=OFF \
      -DBUILD_opencv_imgcodecs=OFF \
      -DBUILD_opencv_python2=OFF \
      -DENABLE_SSE=OFF \
      -DENABLE_SSE2=OFF \
      -DENABLE_SSE3=OFF \
      -DENABLE_SSE41=OFF \
      -DENABLE_SSE42=OFF \
      -DENABLE_SSSE3=OFF \
      -DENABLE_AVX=OFF \
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
      -DWITH_FFMPEG=OFF \
      -DWITH_GIGEAPI=OFF \
      -DWITH_GPHOTO2=OFF \
      -DWITH_GSTREAMER=OFF \
      -DWITH_GSTREAMER_0_10=OFF \
      -DWITH_JASPER=OFF \
      -DWITH_IMAGEIO=OFF \
      -DWITH_IPP=OFF \
      -DWITH_IPP_A=OFF \
      -DWITH_TBB=OFF \
      -DWITH_OPENNI=OFF \
      -DWITH_QT=OFF \
      -DWITH_QUICKTIME=OFF \
      -DWITH_V4L=OFF \
      -DWITH_LIBV4L=OFF \
      -DWITH_MATLAB=OFF \
      -DWITH_OPENCL=OFF \
      -DWITH_OPENCLCLAMDBLAS=OFF \
      -DWITH_OPENCLCLAMDFFT=OFF \
      -DWITH_OPENCL_SVM=OFF \
      -DWITH_WEBP=OFF \
      -DWITH_VTK=OFF \
      -DWITH_PVAPI=OFF \
      -DWITH_EIGEN=OFF \
      -DWITH_GTK=OFF \
      -DWITH_OPENCLAMDBLAS=OFF \
      -DWITH_OPENCLAMDFFT=OFF \
      -DBUILD_TESTS=OFF \
      -DBUILD_PERF_TESTS=OFF
    make -j${PARALLEL_MAKE}
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

    # copy lib
    cp -R $LIB_FOLDER/lib/opencv.a $1/lib/$TYPE/

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

      cp -R include/opencv $1/include/
      cp -R include/opencv2 $1/include/
      cp -R modules/*/include/opencv2/* $1/include/opencv2/

      #copy the ippicv includes and lib
      IPPICV_SRC=build_vs_${ARCH}/3rdparty/ippicv/unpack/ippicv_win
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
    mkdir -p $1/lib/$TYPE
    cp -v lib/$TYPE/*.a $1/lib/$TYPE
  elif [ "$TYPE" == "android" ]; then
    if [ $ABI = armeabi-v7a ] || [ $ABI = armeabi ]; then
      local BUILD_FOLDER="build_android_arm"
    elif [ $ABI = x86 ]; then
      local BUILD_FOLDER="build_android_x86"
    fi
    
    cp -r platforms/$BUILD_FOLDER/install/sdk/native/jni/include/opencv $1/include/
    cp -r platforms/$BUILD_FOLDER/install/sdk/native/jni/include/opencv2 $1/include/
    
    rm -f platforms/$BUILD_FOLDER/lib/$ABI/*pch_dephelp.a
    rm -f platforms/$BUILD_FOLDER/lib/$ABI/*.so
    cp -r platforms/$BUILD_FOLDER/lib/$ABI $1/lib/$TYPE/
    
  elif [ "$TYPE" == "emscripten" ]; then
    cp -r build_emscripten/install/include/* $1/include/
    cp -r build_emscripten/install/lib/*.a $1/lib/$TYPE/
    cp -r build_emscripten/install/share/OpenCV/3rdparty/lib/*.a $1/lib/$TYPE/
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
