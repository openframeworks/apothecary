#!/usr/bin/env bash
# OpenImageIO starter. OpenColorIO and robin-map must be supplied explicitly.
# Opt-in only; dependency formulas and CI publication are not complete yet.

FORMULA_TYPES=("osx" "linux" "vs")
FORMULA_DEPENDS=("imath" "openexr" "libjpeg-turbo" "libtiff" "zlib" "libpng" "fmt")
VER=3.2.2.0
SHA256="fa94876cfbd4c817deaba81ced8bad4af2956689faf4085f277b20197cd70b4e"
BUILD_ID=1
DEFINES=""
URL="https://github.com/AcademySoftwareFoundation/OpenImageIO/archive/refs/tags/v${VER}.tar.gz"

GIT_URL="$URL"

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$URL" || return $?
    verify_sha256 "v${VER}.tar.gz" "$SHA256" || return $?
    tar -xf "v${VER}.tar.gz" || return $?
    mv "OpenImageIO-${VER}" openimageio || return $?
    rm "v${VER}.tar.gz"
}

function prepare() {
    # Repeatable guard; never fall back to CMake-managed network downloads.
    if ! grep -q 'Apothecary requires staged dependencies' src/cmake/dependency_utils.cmake; then
        patch -p1 < "$FORMULA_DIR/no-auto-download.patch" || return $?
    fi
}

function build() {
    local build_dir="$PWD/build_${TYPE}_${PLATFORM}"
    local platform_args=()
    case "$TYPE" in
        osx)
            platform_args=(
                -DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/ios.toolchain.cmake"
                -DPLATFORM="$PLATFORM" -DDEPLOYMENT_TARGET="$MIN_SDK_VER"
                -DENABLE_BITCODE=OFF -DENABLE_ARC=OFF
            ) ;;
        linux)
            platform_args=(-DCMAKE_TOOLCHAIN_FILE="$APOTHECARY_DIR/toolchains/linux${PLATFORM}.toolchain.cmake") ;;
        vs)
            platform_args=(-G "Visual Studio ${VS_VER_GEN}" -A "$PLATFORM" ${CMAKE_WIN_SDK:-})
            platform_args+=(
                "-DCMAKE_C_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
                "-DCMAKE_CXX_FLAGS=${VS_C_FLAGS:-} ${FLAGS_RELEASE:-} ${EXCEPTION_FLAGS:-}"
            )
            unset PKG_CONFIG_PATH PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
            ;;
        *) echoError "Unsupported OpenImageIO target: $TYPE"; return 1 ;;
    esac

    if [ -z "${OPENIMAGEIO_EXTRA_PREFIX:-}" ] || [ ! -d "$OPENIMAGEIO_EXTRA_PREFIX" ]; then
        echoError "OpenImageIO starter: set OPENIMAGEIO_EXTRA_PREFIX to an install prefix containing OpenColorIO >= 2.3 and robin-map >= 1.3. Their Apothecary formulas are still pending."
        return 1
    fi
    local libdir="lib/$TYPE/$PLATFORM"
    local zlib_library="$LIBS_DIR_REAL/zlib/$libdir/zlib.a"
    local png_library="$LIBS_DIR_REAL/libpng/$libdir/libpng.a"
    if [ "$TYPE" = vs ]; then
        zlib_library="$LIBS_DIR_REAL/zlib/$libdir/zlib.lib"
        png_library="$LIBS_DIR_REAL/libpng/$libdir/libpng.lib"
    fi
    # OIIO internalizes header-only fmt. Adapt Apothecary's staged headers to
    # fmt's upstream CMake target without relying on an unrelocated build tree.
    local fmt_dir="$build_dir/apothecary-fmt"
    mkdir -p "$fmt_dir"
    cp "$FORMULA_DIR"/fmt-*.cmake "$fmt_dir/" || return $?
    printf 'set(APOTHECARY_FMT_ROOT "%s")\n' "$LIBS_DIR_REAL/fmt" > "$fmt_dir/root.cmake"
    local dependency_args=() dependency
    # Optional codecs must not be selected from the build host by accident.
    for dependency in libuhdr libdeflate zstd WebP JXL Freetype OpenCV TBB DCMTK FFmpeg GIF Libheif LibRaw OpenJPEG openjph OpenVDB Ptex Nuke Qt5 Qt6 OpenGL; do
        dependency_args+=("-DUSE_$dependency=OFF")
    done

    # Install directly into the Apothecary layout. CMake generates exports with
    # the correct relative prefix depth, preserving upstream names and targets.
    cmake -S . -B "$build_dir" "${platform_args[@]}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$build_dir/Release" \
        -DCMAKE_INSTALL_LIBDIR="lib/$TYPE/$PLATFORM" \
        -DCMAKE_INSTALL_INCLUDEDIR=include \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF \
        -DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF \
        -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF \
        -DCMAKE_PREFIX_PATH="$OPENIMAGEIO_EXTRA_PREFIX" \
        -DImath_DIR="$LIBS_DIR_REAL/imath/$libdir/cmake/Imath" \
        -DOpenEXR_DIR="$LIBS_DIR_REAL/openexr/$libdir/cmake/OpenEXR" \
        -DTIFF_DIR="$LIBS_DIR_REAL/libtiff/$libdir/cmake/tiff" \
        -Dlibjpeg-turbo_DIR="$LIBS_DIR_REAL/libjpeg-turbo/$libdir/cmake/libjpeg-turbo" \
        -Dfmt_DIR="$fmt_dir" \
        -DZLIB_LIBRARY="$zlib_library" -DZLIB_INCLUDE_DIR="$LIBS_DIR_REAL/zlib/include" \
        -DPNG_LIBRARY="$png_library" -DPNG_PNG_INCLUDE_DIR="$LIBS_DIR_REAL/libpng/include" \
        -DOIIO_LOCAL_DEPS_PATH="$build_dir/no-host-deps" \
        -DOpenImageIO_BUILD_MISSING_DEPS= -DOpenImageIO_BUILD_LOCAL_DEPS= \
        -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF -DUSE_PYTHON=OFF \
        -DUSE_QT=OFF -DOIIO_USE_HWY=OFF -DUSE_SIMD=0 \
        -DEMBEDPLUGINS=ON -DOIIO_INTERNALIZE_FMT=ON -DOIIO_USE_COMPILED_FMT=OFF \
        -DBUILD_DOCS=OFF -DINSTALL_DOCS=OFF \
        "${dependency_args[@]}" || return $?
    cmake --build "$build_dir" --config Release -j"${PARALLEL_MAKE:-4}" --target install
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    local library metadata_name extension=a count=0
    [ "$TYPE" != vs ] || extension=lib
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/license"
    cp -R "$prefix/include/." "$1/include/" || return $?
    cp -R "$prefix/lib/$TYPE/$PLATFORM/." "$1/lib/$TYPE/$PLATFORM/" || return $?
    cp LICENSE.md "$1/license/" || return $?

    . "$SECURE_SCRIPT"
    for library in "$1/lib/$TYPE/$PLATFORM/"*."$extension"; do
        [ -f "$library" ] || continue
        count=$((count + 1))
        metadata_name=$(basename "$library")
        [ "$TYPE" = vs ] || metadata_name="${metadata_name#lib}"
        secure "$library" "$metadata_name" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SHA256" || return $?
    done
    [ "$count" -gt 0 ] || { echoError "No installed OpenImageIO archives for $TYPE/$PLATFORM"; return 1; }
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}

# No remote binary cache until this opt-in formula has published artifacts.
function load() { echo 0; }
