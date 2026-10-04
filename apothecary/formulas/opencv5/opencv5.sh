#!/usr/bin/env bash
#
# OpenCV 5 — standalone modular package (not part of the core archive)
# library of programming functions mainly aimed at real-time computer vision
# http://opencv.org
#
# uses a CMake build system

FORMULA_TYPES=("osx" "ios" "catos" "xros" "tvos" "vs" "msys2" "android" "emscripten" "linux" )
FORMULA_DEPENDS=("zlib" "libpng" )

# define the version
VER=5.0.0
SHA256="b0528f5a1d379d59d4701cb28c36e22214cc51cf64594e5b56f2d3e6c0233095"
BUILD_ID=3
DEFINES=""
FRAMEWORKS=""
FILE_VERSION=500

# tools for git use
GIT_URL=https://github.com/opencv/opencv
GIT_TAG=$VER

GIT_CONTRIB_URL=https://github.com/opencv/opencv_contrib
VER_CONTRIB=$VER
SHA256_CONTRIB="c58f6344170c39abf187c56f3843b59cab1fd3e89cf19ba2ce25dc061659b27f"

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"
    downloader $GIT_URL/archive/refs/tags/$VER.tar.gz
    verify_sha256 "$VER.tar.gz" "$SHA256"
    tar -xzf $VER.tar.gz
    mv opencv-$VER opencv5
    rm $VER.tar.gz

    downloader $GIT_CONTRIB_URL/archive/refs/tags/$VER.tar.gz
    verify_sha256 "$VER.tar.gz" "$SHA256_CONTRIB"
    tar -xzf $VER.tar.gz
    mv opencv_contrib-$VER opencv5/opencv_contrib
    rm $VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    : # noop

    # OpenCV 5.0.0 includes <exception>; the OpenCV 4 patch is unnecessary.

    if [[ "$TYPE" =~ ^(vs|msys2)$ ]]; then
        # Vendored MLAS depends on assembly/POSIX APIs unsupported on Windows.
        # Keep DNN enabled using its built-in SGEMM fallback.
        if ! grep -q 'vendored MLAS kernels unsupported on Windows' 3rdparty/mlas/CMakeLists.txt; then
            patch -p1 < "$FORMULA_DIR/windows-mlas-fallback.patch"
        fi
    fi
    if [ "$TYPE" == "vs" ]; then
        rm -rf modules/objc_bindings_generator
        rm -rf modules/objc
    fi

    rm -f ./modules/imgcodecs/src/ios_conversions.mm
    cp $FORMULA_DIR/ios_conversions.mm ./modules/imgcodecs/src/ios_conversions.mm

    # OpenCV loads cmake/platforms/OpenCV-${CMAKE_SYSTEM_NAME}.cmake.
    # There is no stock OpenCV-tvOS.cmake / OpenCV-watchOS.cmake.
    mkdir -p cmake/platforms
    cp "$FORMULA_DIR/OpenCV-tvOS.cmake" cmake/platforms/OpenCV-tvOS.cmake
    cp "$FORMULA_DIR/OpenCV-watchOS.cmake" cmake/platforms/OpenCV-watchOS.cmake
    cp "$FORMULA_DIR/OpenCV-visionOS.cmake" cmake/platforms/OpenCV-visionOS.cmake

    # imgcodecs: APPLE && !IOS && !XROS → macosx_conversions.mm (AppKit).
    # tvOS/watchOS/visionOS are Apple but not macOS.
    IMGCODECS_CMAKE=modules/imgcodecs/CMakeLists.txt
    if [ -f "$IMGCODECS_CMAKE" ] && ! grep -q 'CMAKE_SYSTEM_NAME STREQUAL "tvOS"' "$IMGCODECS_CMAKE"; then
        perl -pi -e 's/if\(APPLE AND \(NOT IOS\) AND \(NOT XROS\)\)/if(APPLE AND (NOT IOS) AND (NOT XROS) AND (NOT CMAKE_SYSTEM_NAME STREQUAL "tvOS") AND (NOT CMAKE_SYSTEM_NAME STREQUAL "watchOS") AND (NOT CMAKE_SYSTEM_NAME STREQUAL "visionOS"))/' "$IMGCODECS_CMAKE"
    fi

    if [[ "$TYPE" =~ ^(tvos|watchos|xros)$ ]]; then
        cat >./modules/imgcodecs/src/macosx_conversions.mm <<'EOF'
// AppKit is not available on tvOS/watchOS/visionOS.
#include <TargetConditionals.h>
EOF
    fi
}

# executed inside the lib src dir
function build() {
    # Use one install layout across desktop, Apple mobile, Android and WASM.
    # These final arguments also prevent variant overrides from enabling world.
    local opencv5_defs=(
        -DBUILD_opencv_world=OFF
        -DBUILD_SHARED_LIBS=OFF
        -DBUILD_TESTS=OFF
        -DBUILD_PERF_TESTS=OFF
        -DBUILD_EXAMPLES=OFF
        -DCMAKE_CXX_STANDARD=17
        -DOPENCV_INCLUDE_INSTALL_PATH=include
        -DOPENCV_LIB_INSTALL_PATH=lib
        -DOPENCV_LIB_ARCHIVE_INSTALL_PATH=lib
        -DOPENCV_3P_LIB_INSTALL_PATH=lib/3rdparty
        -DOPENCV_OTHER_INSTALL_PATH=etc
        -DOPENCV_LICENSES_INSTALL_PATH=etc/licenses
    )
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
        -DBUILD_ANDROID_EXAMPLES=OFF \
        -DINSTALL_ANDROID_EXAMPLES=OFF \
        -DINSTALL_PYTHON_EXAMPLES=OFF \
        -DINSTALL_C_EXAMPLES=OFF \
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
        -DBUILD_opencv_calib=ON \
        -DBUILD_opencv_objdetect=ON \
        -DBUILD_opencv_world=OFF \
        -DOPENCV_ENABLE_NONFREE=OFF \
        -DWITH_PNG=ON \
        -DBUILD_TIFF=OFF \
        -DBUILD_OPENJPEG=OFF \
        -DBUILD_PNG=OFF \
        -DWITH_1394=OFF \
        -DWITH_IMGCODEC_HDR=ON \
        -DWITH_CARBON=OFF \
        -DWITH_JPEG=OFF \
        -DWITH_OPENJPEG=OFF \
        -DWITH_TIFF=OFF \
        -DWITH_FFMPEG=ON \
        -DWITH_QUIRC=ON \
        -DWITH_GIGEAPI=OFF \
        -DBUILD_OBJC=ON \
        -DWITH_CUDA=OFF \
        -DWITH_METAL=ON \
        -DWITH_CUFFT=OFF \
        -DWITH_JASPER=OFF \
        -DWITH_LIBV4L=OFF \
        -DWITH_IMAGEIO=OFF \
        -DWITH_IPP=OFF \
        -DWITH_OPENCL=OFF \
        -DWITH_OPENNI=OFF \
        -DWITH_OPENNI2=OFF \
        -DBUILD_OPENEXR=OFF \
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
        "

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
            EXTRA_DEFS="$EXTRA_DEFS -DBUILD_opencv_videoio=ON -DBUILD_opencv_videostab=ON"
        fi

        # Keep CMAKE_SYSTEM_NAME from ios-cmake 4.6 (tvOS/watchOS/visionOS).
        # OpenCV-*.cmake + imgcodecs patch skip AppKit/Cocoa.
        if [ "$TYPE" == "tvos" ]; then
            # tvOS has AVFoundation (playback); it does not have AppKit or a camera.
            EXTRA_DEFS="$EXTRA_DEFS -DWITH_CAP_IOS=OFF -DBUILD_opencv_highgui=OFF"
        elif [ "$TYPE" == "watchos" ]; then
            EXTRA_DEFS="$EXTRA_DEFS -DWITH_CAP_IOS=OFF -DWITH_AVFOUNDATION=OFF -DBUILD_opencv_highgui=OFF"
        elif [ "$TYPE" == "xros" ]; then
            EXTRA_DEFS="$EXTRA_DEFS -DXROS=ON -DBUILD_opencv_highgui=OFF"
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
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            "${opencv5_defs[@]}"

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
                -DBUILD_EXAMPLES=OFF \
                -DBUILD_ANDROID_EXAMPLES=OFF \
                -DINSTALL_ANDROID_EXAMPLES=OFF \
                -DINSTALL_PYTHON_EXAMPLES=OFF \
                -DINSTALL_C_EXAMPLES=OFF \
                -DWITH_FFMPEG=ON \
                -DWITH_WIN32UI=OFF \
                -DBUILD_PACKAGE=OFF \
                -DWITH_JASPER=OFF \
                -DWITH_GIGEAPI=OFF \
                -DWITH_JPEG=OFF \
                -DWITH_OPENJPEG=OFF \
                -DBUILD_WITH_DEBUG_INFO=OFF \
                -DBUILD_TIFF=OFF \
                -DWITH_TIFF=OFF \
                -DBUILD_JPEG=OFF \
                -DBUILD_OPENJPEG=OFF \
                -DWITH_OPENJPEG=OFF \
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
                -DBUILD_opencv_calib=ON \
                -DBUILD_PERF_TESTS=OFF \
                -DBUILD_opencv_world=OFF \
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
                -DBUILD_ZLIB=ON \
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
                -DOPENCV_DNN_CUDA=ON \
                -DENABLE_FAST_MATH=ON"
        else
            export DEFINES="$DEFINES \
                -DWITH_CUDA=OFF \
                -DWITH_CUDNN=OFF \
                -DWITH_CUBLAS=OFF \
                -DWITH_CUFFT=OFF"
        fi

        # CMake otherwise finds MinGW iconv and injects MinGW CRT headers into
        # the MSVC WeChat QR module. Its built-in NO_ICONV path avoids this.
        export DEFINES="${DEFINES} ${OPENCV_EXTRA_DEFINES:-} -DCMAKE_DISABLE_FIND_PACKAGE_Iconv=ON"

		echoInfo "Building with OPENCV_STATIC"
		export DEFINES="${DEFINES} \
		-DBUILD_SHARED_LIBS=OFF"
		if [ $MULTITHREADED_TYPE == "MD" ]; then
			sed -i 's/\/MT/\/MD/g; s/\/MTd/\/MDd/g' ../CMakeLists.txt
		fi

		echoInfo "Building OpenCV Debug"
		cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            ${CMAKE_VS_MT_DEBUG} \
            ${MT_TYPE_DEFINES} \
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
            -DBUILD_PNG=OFF \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            "${opencv5_defs[@]}"
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

        echoInfo "Building OpenCV Release"
        cmake .. ${DEFINES} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}" \
            ${CMAKE_VS_MT_RELEASE} \
            ${MT_TYPE_DEFINES} \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_BUILD_TYPE="Release" \
            -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_SYSTEM_PROCESSOR="${PLATFORM}" \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            ${EXTRA_DEFS} \
            -DBUILD_PNG=OFF \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            ${CMAKE_WIN_SDK} \
            "${opencv5_defs[@]}"
        cmake --build . --target install --config Release -j${PARALLEL_MAKE}
        cd ..

        if [ -d "Debug" ]; then
            mv "Debug" build_${TYPE}_${PLATFORM}/Debug
            mv "Debug3rd" build_${TYPE}_${PLATFORM}/3rdparty/lib/Debug
        fi

    elif [ "$TYPE" == "msys2" ]; then
        echoInfo "building $TYPE | $ARCH | $PLATFORM"
        echoInfo "--------------------"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt || true

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        ZLIB_DEFS="-DBUILD_ZLIB=ON -DWITH_ZLIB=ON"
        if [ -f "$ZLIB_LIBRARY" ]; then
            ZLIB_DEFS="-DBUILD_ZLIB=OFF -DWITH_ZLIB=ON \
                -DZLIB_ROOT=${ZLIB_ROOT} \
                -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
                -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
                -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR}"
        fi

        # Build the pinned OpenCV 5 sources independently of MSYS2 packages.
        export DEFINES="
                -DCMAKE_C_STANDARD=${C_STANDARD} \
                -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
                -DCMAKE_CXX_STANDARD_REQUIRED=ON \
                -DCMAKE_CXX_EXTENSIONS=OFF \
                -DBUILD_SHARED_LIBS=OFF \
                -DCMAKE_INSTALL_PREFIX=Release \
                -DCMAKE_INSTALL_INCLUDEDIR=include \
                -DCMAKE_INSTALL_LIBDIR=lib \
                -DOPENCV_ENABLE_NONFREE=OFF \
                -DOPENCV_GENERATE_PKGCONFIG=ON \
                -DENABLE_PRECOMPILED_HEADERS=OFF \
                -DBUILD_TESTS=OFF \
                -DBUILD_PERF_TESTS=OFF \
                -DBUILD_EXAMPLES=OFF \
                -DBUILD_DOCS=OFF \
                -DBUILD_PACKAGE=OFF \
                -DBUILD_opencv_python=OFF \
                -DBUILD_opencv_python2=OFF \
                -DBUILD_opencv_python3=OFF \
                -DBUILD_opencv_java=OFF \
                -DBUILD_opencv_apps=OFF \
                -DBUILD_opencv_world=OFF \
                -DBUILD_opencv_highgui=OFF \
                -DBUILD_opencv_imgcodecs=ON \
                -DBUILD_opencv_videoio=OFF \
                -DBUILD_opencv_videostab=OFF \
                -DBUILD_opencv_stitching=ON \
                -DBUILD_opencv_calib=ON \
                -DBUILD_opencv_objdetect=ON \
                -DWITH_FFMPEG=OFF \
                -DWITH_GSTREAMER=OFF \
                -DWITH_MSMF=OFF \
                -DWITH_DSHOW=OFF \
                -DWITH_VFW=OFF \
                -DWITH_WIN32UI=OFF \
                -DWITH_GTK=OFF \
                -DWITH_QT=OFF \
                -DWITH_OPENGL=OFF \
                -DWITH_OPENCL=OFF \
                -DWITH_CUDA=OFF \
                -DWITH_IPP=OFF \
                -DWITH_TBB=OFF \
                -DWITH_OPENMP=OFF \
                -DWITH_EIGEN=OFF \
                -DWITH_JPEG=OFF \
                -DWITH_TIFF=OFF \
                -DWITH_WEBP=OFF \
                -DWITH_OPENEXR=OFF \
                -DWITH_OPENJPEG=OFF \
                -DWITH_JASPER=OFF \
                -DWITH_PNG=ON \
                -DBUILD_PNG=ON \
                -DBUILD_JPEG=OFF \
                -DBUILD_TIFF=OFF \
                -DWITH_1394=OFF \
                -DWITH_VTK=OFF \
                -DWITH_LAPACK=OFF \
                -DWITH_ADE=OFF \
                ${ZLIB_DEFS}"

        # CMake writes SIMD dispatch headers with MSYS paths like
        # #include "/d/a/.../arithm.simd.hpp". Clang/GCC as Win32 compilers
        # do not resolve that, so skip CPU dispatch on MinGW.
        EXTRA_DEFS="-DCV_DISABLE_OPTIMIZATION=ON -DCV_ENABLE_INTRINSICS=OFF -DCPU_DISPATCH= -DCPU_BASELINE= -DWITH_NEON=OFF -DENABLE_NEON=OFF -DPNG_ARM_NEON=off"

        cmake .. ${DEFINES} \
            ${EXTRA_DEFS} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_CXX_FLAGS="${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="${FLAG_RELEASE}" \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            "${opencv5_defs[@]}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    elif [ "$TYPE" == "android" ]; then
        export ANDROID_NDK=${NDK_ROOT}

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"
        
        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

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
        -DBUILD_ANDROID_EXAMPLES=OFF \
        -DINSTALL_ANDROID_EXAMPLES=OFF \
        -DINSTALL_PYTHON_EXAMPLES=OFF \
        -DINSTALL_C_EXAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_FAT_JAVA_LIB=OFF \
        -DBUILD_JASPER=OFF \
        -DBUILD_PACKAGE=OFF \
        -DBUILD_opencv_java=OFF \
        -DBUILD_opencv_java_android=OFF \
        -DBUILD_opencv_python=OFF \
        -DBUILD_opencv_python2=OFF \
        -DBUILD_opencv_python3=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_opencv_highgui=ON \
        -DBUILD_opencv_imgcodecs=ON \
        -DBUILD_opencv_stitching=ON \
        -DBUILD_opencv_calib=ON \
        -DBUILD_opencv_objdetect=ON \
        -DBUILD_opencv_world=OFF \
        -DOPENCV_ENABLE_NONFREE=OFF \
        -DWITH_PNG=ON \
        -DBUILD_OPENEXR=OFF \
        -DWITH_OPENEXR=OFF \
        -DBUILD_OPENJPEG=OFF \
        -DWITH_OPENJPEG=OFF \
        -DBUILD_PNG=OFF \
        -DWITH_1394=OFF \
        -DWITH_IMGCODEC_HDR=ON \
        -DWITH_JPEG=OFF \
        -DWITH_TIFF=OFF \
        -DBUILD_TIFF=OFF \
        -DWITH_FFMPEG=ON \
        -DWITH_QUIRC=ON \
        -DWITH_GIGEAPI=OFF \
        -DBUILD_OBJC=ON \
        -DWITH_CUDA=OFF \
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
        -DHAVE_opencv_androidcamera=ON \
        -DWITH_ITT=OFF \
        -DWITH_CAROTENE=OFF \
        "

        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        rm -f CMakeCache.txt *.a *.o

        if [ "$ABI" = "armeabi-v7a" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=TRUE"
        elif [ $ABI = "arm64-v8a" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        elif [ "$ABI" = "x86_64" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        elif [ "$ABI" = "x86" ]; then
            export ARM_MODE="-DANDROID_FORCE_ARM_BUILD=FALSE"
        fi

        if [[ "$ABI" =~ ^(armeabi-v7a|arm64-v8a)$ ]]; then # Enable NEON with VFPv3
            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='NEON;VFPV3' -DCPU_DISPATCH=''"
        else
            #EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=ON -DCPU_BASELINE='SSE2' -DCPU_DISPATCH='SSE4_1;SSE4_2'"
            EXTRA_DEFS="-DCV_ENABLE_INTRINSICS=OFF "
        fi

        cmake .. ${CORE_DEFS} ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_VERBOSE_MAKEFILE=ON \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            "${opencv5_defs[@]}"
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        cd ..

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

        LIBPNG_ROOT="$LIBS_ROOT/libpng/"
        LIBPNG_INCLUDE_DIR="$LIBS_ROOT/libpng/include"
        LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng16.a"
        if [ ! -f "$LIBPNG_LIBRARY" ]; then
            LIBPNG_LIBRARY="$LIBS_ROOT/libpng/lib/$TYPE/$PLATFORM/libpng.a"
        fi

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
        -DBUILD_opencv_apps=OFF \
        -DBUILD_opencv_python=OFF \
        -DBUILD_opencv_java=OFF \
        -DBUILD_ANDROID_EXAMPLES=OFF \
        -DINSTALL_ANDROID_EXAMPLES=OFF \
        -DINSTALL_PYTHON_EXAMPLES=OFF \
        -DINSTALL_C_EXAMPLES=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_opencv_highgui=ON \
        -DBUILD_opencv_imgcodecs=ON \
        -DBUILD_opencv_stitching=ON \
        -DBUILD_opencv_calib=ON \
        -DBUILD_opencv_objdetect=ON \
        -DBUILD_opencv_videoio=ON \
        -DBUILD_opencv_videostab=ON \
        -DOPENCV_ENABLE_NONFREE=OFF \
        -DBUILD_TIFF=OFF \
        -DWITH_TIFF=OFF \
        -DBUILD_JPEG=OFF \
        -DWITH_JPEG=OFF \
        -DWITH_OPENJPEG=OFF \
        -DBUILD_OPENJPEG=OFF \
        -DBUILD_OPENEXR=OFF \
        -DWITH_PNG=ON \
        -DBUILD_PNG=OFF \
        -DWITH_FFMPEG=ON \
        -DWITH_GSTREAMER=ON \
        -DWITH_V4L=ON \
        -DWITH_EIGEN=ON \
        -DBUILD_TESTS=OFF \
        -DWITH_OPENGL=OFF \
        -DWITH_VULKAN=OFF \
        -DWITH_OPENJPEG=OFF \
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
                -DWITH_CUDNN=${OPENCV_WITH_CUDNN:-ON} \
                -DOPENCV_DNN_CUDA=ON \
                -DCUDA_ARCH_BIN='6.1;7.5;8.6;8.9;9.0' \
                -DCUDA_ARCH_PTX='9.0'"
        fi

        # Modular variants can add CMake features without changing the core
        # OpenCV configuration or its cache identity.
        DEFINES="${DEFINES} ${OPENCV_EXTRA_DEFINES:-}"

        cmake .. ${CORE_DEFS} ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DPLATFORM=$PLATFORM \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DPNG_HARDWARE_OPTIMIZATIONS=ON \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            "${opencv5_defs[@]}"
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

        DEFINES="-DCPU_BASELINE='WASM_SIMD' \
            -DCPU_DISPATCH='' \
            -DCV_ENABLE_INTRINSICS=ON \
            -DCV_TRACE=OFF \
            -DOPENCV_ENABLE_NONFREE=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DBUILD_DOCS=OFF \
            -DBUILD_EXAMPLES=OFF \
            -DBUILD_ANDROID_EXAMPLES=OFF \
            -DINSTALL_ANDROID_EXAMPLES=OFF \
            -DINSTALL_PYTHON_EXAMPLES=OFF \
            -DINSTALL_C_EXAMPLES=OFF \
            -DBUILD_TESTS=OFF \
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
            -DBUILD_opencv_features=ON \
            -DBUILD_opencv_flann=ON \
            -DBUILD_opencv_photo=OFF \
            -DBUILD_opencv_python=OFF \
            -DBUILD_opencv_shape=OFF \
            -DBUILD_opencv_stitching=OFF \
            -DBUILD_opencv_superres=OFF \
            -DBUILD_opencv_ts=OFF \
            -DBUILD_opencv_calib=ON \
            -DBUILD_opencv_world=OFF \
            -DBUILD_TIFF=OFF \
            -DWITH_TIFF=OFF \
            -DBUILD_JPEG=OFF \
            -DWITH_JPEG=OFF \
            -DWITH_OPENJPEG=OFF \
            -DBUILD_OPENJPEG=OFF \
            -DBUILD_OPENEXR=OFF \
            -DBUILD_IPP_IW=OFF \
            -DWITH_MATLAB=OFF \
            -DWITH_CUDA=OFF \
            -DWITH_TIFF=OFF \
            -DBUILD_TIFF=OFF \
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
            -DWITH_OPENJPEG=OFF \
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
            -DBUILD_WASM_INTRIN_TESTS=OFF"

        $EMSDK/upstream/emscripten/emcmake cmake .. \
            -B . \
            ${DEFINES} \
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
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DPNG_ROOT=${LIBPNG_ROOT} \
            -DPNG_PNG_INCLUDE_DIR=${LIBPNG_INCLUDE_DIR} \
            -DPNG_LIBRARY=${LIBPNG_LIBRARY} \
            "${opencv5_defs[@]}"

        cmake --build . --target install --config Release
    fi

}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    local dest="$1"
    local build_dir="build_${TYPE}_${PLATFORM}"
    [ "$TYPE" != "msys2" ] || build_dir="build_${TYPE}_${ARCH}"
    local config install_dir lib_dest library core
    local configs=(Release)
    [ "$TYPE" != "vs" ] || configs=(Debug Release)

    mkdir -p "$dest/include" "$dest/license" "$dest/etc"
    cp -R "$build_dir/Release/include/." "$dest/include/"
    cp LICENSE "$dest/license/"
    if [ -d "$build_dir/Release/etc" ]; then
        cp -R "$build_dir/Release/etc/." "$dest/etc/"
    fi
    if [ -d "$build_dir/Release/etc/licenses" ]; then
        cp -R "$build_dir/Release/etc/licenses/." "$dest/license/"
    fi
    . "$SECURE_SCRIPT"
    for config in "${configs[@]}"; do
        install_dir="$build_dir/$config"
        lib_dest="$dest/lib/$TYPE/$PLATFORM"
        core=libopencv_core.a
        if [ "$TYPE" = "vs" ]; then
            lib_dest="$lib_dest/$config"
            core="opencv_core${FILE_VERSION}.lib"
            [ "$config" != "Debug" ] || core="opencv_core${FILE_VERSION}d.lib"
        elif [ "$TYPE" = "msys2" ]; then
            core="libopencv_core${FILE_VERSION}.a"
        fi
        mkdir -p "$lib_dest"
        while IFS= read -r library; do
            cp -v "$library" "$lib_dest/"
        done < <(find "$install_dir/lib" -type f \( -name '*.a' -o -name '*.lib' \))
        if [ ! -f "$lib_dest/$core" ]; then
            echo "Missing OpenCV 5 core library: $lib_dest/$core" >&2
            return 1
        fi
        secure "$lib_dest/$core" "opencv5.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    done
}

# executed inside the lib src dir
function clean() {
    if [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten|linux)$ ]]; then
        if [ -d "build_${TYPE}_${PLATFORM}" ]; then
            rm -r build_${TYPE}_${PLATFORM}
        fi
    elif [ "$TYPE" == "msys2" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "opencv5" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
