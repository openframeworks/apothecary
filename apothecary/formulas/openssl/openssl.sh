#!/usr/bin/env bash
#
# openssl

# define the version
FORMULA_TYPES=("vs" "osx" "ios" "tvos" "xros" "catos" "watchos" "linux" "android" )
FORMULA_DEPENDS=("zlib")

# OpenSSL 4.0.2 + danoli3/openssl-cmake branch 4.0 (test pin for PR #562)
# Note: openssl-cmake 3.5 + 3.5.7 failed CI (ML-DSA DTLS capability macros).
VER=4.0.2
VERDIR=4.0.0
VER_TAG="4.0"
OPENSSL_CMAKE_COMMIT=83f28a9791bb3189e125a9e21ff9bae3cd4d55f5
SHA1=236d35817b0adda5c07572ae24bcbe643b05c71d
SHA256=736b467530f916737b7031310ccb21d8218c6229e61e8e160cd1d3458cd543a8

BUILD_ID=12

CSTANDARD=c17 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=https://www.openssl.org
GIT_URL=https://github.com/danoli3/openssl-cmake

# openssl-cmake uses OPENSSL_ASM (not OPENSSL_NO_ASM) as the master switch.
# Enable assembly where the platform toolchain supports it. The Visual Studio
# branch below still overrides this because its static build has no complete
# NASM/MASM pipeline.
DEFINES="-DOPENSSL_NO_DEPRECATED=OFF \
	-DOPENSSL_NO_COMP=ON \
	-DOPENSSL_NO_EC_NISTP_64_GCC_128=ON \
	-DOPENSSL_NO_ENGINE=ON \
	-DOPENSSL_NO_MD2=OFF \
	-DOPENSSL_NO_RC5=OFF \
	-DOPENSSL_NO_RFC3779=OFF \
	-DOPENSSL_NO_SCTP=ON \
	-DOPENSSL_NO_SSL_TRACE=ON \
	-DOPENSSL_NO_SSL3=OFF \
	-DOPENSSL_NO_STORE=ON \
	-DOPENSSL_NO_UNIT_TEST=ON \
	-DOPENSSL_NO_WEAK_SSL_CIPHERS=OFF \
	-DOPENSSL_NO_ASAN=ON \
	-DOPENSSL_ASM=ON \
	-DOPENSSL_NO_ASM=OFF \
	-DOPENSSL_NO_CRYPTO_MDEBUG=ON \
	-DOPENSSL_NO_DEVCRYPTOENG=ON \
	-DOPENSSL_NO_EGD=ON \
	-DOPENSSL_NO_EXTERNAL_TESTS=ON \
	-DOPENSSL_NO_FUZZ_AFL=ON \
	-DOPENSSL_NO_FUZZ_LIBFUZZER=ON \
	-DOPENSSL_NO_MSAN=ON \
	-DOPENSSL_NO_UBSAN=ON \
	-DOPENSSL_NO_UNIT_TEST=ON \
	-DOPENSSL_NO_STATIC_ENGINE=OFF \
	-DOPENSSL_STATIC_ENGINE=ON \
	-DOPENSSL_THREADS=ON \
	-DOPENSSL_RAND_SEED=os \
	-DOPENSSL_BUILD_APPS=OFF \
	-DBUILD_TESTING=OFF \
	-DOPENSSL_NO_AFALGENG=ON \
	-DOPENSSL_ZLIB=ON \
	-DOPENSSL_BUILD_DOCS=OFF"

# download the source code and unpack it into LIB_NAME
function download() {

    . "$DOWNLOADER_SCRIPT"
    FILE_NAME=openssl-$VER

    if ! [ -f $FILE_NAME ]; then
        downloader "${MIRROR}/source/${FILE_NAME}.tar.gz"
    fi

    if ! [ -f $FILE_NAME.sha1 ]; then
        downloader ${MIRROR}/source/$FILE_NAME.tar.gz.sha1
    fi

    verify_sha256 "$FILE_NAME.tar.gz" "$SHA256"
    CHECKSHA=$(shasum $FILE_NAME.tar.gz | cut -d ' ' -f1)

    # Extract only the SHA value from the .sha1 file
    FILESUM=$(cut -d ' ' -f1 "$FILE_NAME.tar.gz.sha1")


    # Check if CHECKSHA matches both FILESUM and the expected SHA1
    if [[ "$CHECKSHA" != "$FILESUM" || "$CHECKSHA" != "$SHA1" ]]; then
        echo "SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] FILESUM=[$FILESUM] - Developer has not updated SHA or Man in the Middle Attack"
        exit 1
    else
        tar -xf "${FILE_NAME}.tar.gz"
        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
        mv $FILE_NAME openssl_temp
        rm $FILE_NAME.tar.gz
        rm $FILE_NAME.tar.gz.sha1
    fi
    # Clone the openssl-cmake repository
    git clone --branch $VER_TAG $GIT_URL openssl_cmake_temp
    git -C openssl_cmake_temp checkout "$OPENSSL_CMAKE_COMMIT"
    verify_git_commit openssl_cmake_temp "$OPENSSL_CMAKE_COMMIT"

    # Organize directories as needed
    mkdir -p openssl
    mkdir -p openssl/openssl
    mv openssl_temp/* openssl/openssl

    rm -rf openssl_cmake_temp/openssl
    mv openssl_cmake_temp/* openssl/

    rm -rf openssl_temp openssl_cmake_temp
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    apothecaryDependencies download
    apothecaryDepend prepare zlib
    apothecaryDepend build zlib
    apothecaryDepend copy zlib

    if grep -q '^option(OPENSSL_BUILD_APPS ' CMakeLists.txt; then
        echo "disable-apps.patch already applied"
    elif patch --batch --forward -p1 <"$FORMULA_DIR/disable-apps.patch"; then
        echo "disable-apps.patch applied successfully"
    else
        echo "Failed to apply disable-apps.patch"
        exit 1
    fi

    if grep -q 'OPENSSL_RAND_SEED_.*CACHE BOOL.*FORCE)' CMakeLists.txt; then
        echo "rand-seed.patch already applied"
    elif patch --batch --forward -p1 <"$FORMULA_DIR/rand-seed.patch"; then
        echo "rand-seed.patch applied successfully"
    else
        echo "Failed to apply rand-seed.patch"
        exit 1
    fi

    # openssl-cmake 4.0 WIP: some provider CMakeLists incorrectly list
    # ${CMAKE_BINARY_DIR}/providers/implementations/include as a SOURCES
    # entry (directory path). Strip those lines so headers resolve from
    # the OpenSSL source tree like the 3.4/3.5 cmake branches.
    # See: https://github.com/danoli3/openssl-cmake/tree/4.0
    if [[ "$VER_TAG" == "4.0" || "$VER" == 4.* ]]; then
        echo "openssl prepare: patching openssl-cmake 4.x provider SOURCES lists"
        local f
        for f in \
            providers/common/CMakeLists.txt \
            providers/default/CMakeLists.txt \
            providers/legacy/CMakeLists.txt; do
            if [ -f "$f" ]; then
                # Remove lines that are only the broken binary-dir include path
                # (optionally followed by whitespace). Keep real source paths.
                if [[ "$(uname -s)" == "Darwin" ]]; then
                    sed -i '' \
                        -e '/^[[:space:]]*\${CMAKE_BINARY_DIR}\/providers\/implementations\/include[[:space:]]*$/d' \
                        "$f"
                else
                    sed -i \
                        -e '/^[[:space:]]*\${CMAKE_BINARY_DIR}\/providers\/implementations\/include[[:space:]]*$/d' \
                        "$f"
                fi
            fi
        done
    fi

    echo "prepare"
}

# executed inside the lib src dir
function build() {

    LIBS_ROOT=$(realpath $LIBS_DIR)
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        BUILD_SUBDIR="build_${TYPE}_${PLATFORM}"
        if [ "$TYPE" == "catos" ]; then
            BUILD_SUBDIR="${BUILD_SUBDIR}_${ARCH}"
        fi
        mkdir -p "$BUILD_SUBDIR"
        cd "$BUILD_SUBDIR"

        # if [[ "$TYPE" =~ ^(tvos|xros|catos|watchos)$ ]]; then
        # 	# LANG=C sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "./openssl/apps/speed.c"
        # 	# Patch Configure to build for tvOS, not iOS
        # 	# LANG=C sed -i -- 's/D\_REENTRANT\:iOS/D\_REENTRANT\:tvOS/' "./openssl/Configure"
        # fi

        DEFINES="${DEFINES} \
            -DNO_FORK=ON \
            -DOPENSSL_OCSP=ON \
            -DOPENSSL_CMP=OFF \
            "
        if [[ "$TYPE" =~ ^(ios|tvos|xros|catos|watchos)$ ]]; then
            DEFINES="${DEFINES} -DHAVE_FORK=0"
        fi
        # openssl-cmake currently selects the ELF perlasm flavour for Mac
        # Catalyst. The generated sources contain directives such as .hidden,
        # .type and .section .init, which AppleClang's Mach-O assembler rejects.
        # Use OpenSSL's portable C implementation for Catalyst until the CMake
        # wrapper passes a Catalyst-aware Darwin perlasm target.
        if [ "$TYPE" == "catos" ]; then
            DEFINES="${DEFINES} -DOPENSSL_ASM=OFF -DOPENSSL_NO_ASM=ON"
        fi
        rm -f CMakeCache.txt *.a *.o
        cmake .. \
            ${DEFINES} \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_TESTING=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DDEPLOYMENT_TARGET=${MIN_SDK_VER} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_IGNORE_PATH=/opt/homebrew \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DCMAKE_MACOSX_BUNDLE=OFF \
            -DENABLE_ARC=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_VISIBILITY=OFF
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        cd "Release/lib/"
        # Rename with prefixes (including library origin to avoid duplicates)
        mkdir -p crypto
        mkdir -p ssl
        mv libcrypto.a crypto/libcrypto.a
        mv libssl.a ssl/libssl.a
        cd crypto
        ar -x libcrypto.a
        for f in *.o; do mv "$f" "openssl_${ARCH}_crypto_$f"; done
        for obj in *.o; do
            if [ -z "$(nm "$obj")" ]; then
                echo "Removing empty object file: $obj"
                rm -f "$obj"
            fi
        done
        ar rcs "../libcrypto.a" openssl_${ARCH}_crypto_*.o
        cd ../ssl
        ar -x libssl.a
        for f in *.o; do mv "$f" "openssl_${ARCH}_ssl_$f"; done
         for obj in *.o; do
            if [ -z "$(nm "$obj")" ]; then
                echo "Removing empty object file: $obj"
                rm -f "$obj"
            fi
        done
        ar rcs "../libssl.a" openssl_${ARCH}_ssl_*.o
        cd ..
        echo "Verifying libcrypto.:"
        lipo -info "libcrypto.a"
        echo "Verifying libssl.a"
        lipo -info "libssl.a"
        rm -rf crypto ssl
        cd ..

    elif [[ "$TYPE" =~ ^(android)$ ]]; then

        source $APOTHECARY_DIR/configure/android_configure.sh $ABI cmake

        # OpenSSL 4.0.1's ARM64 Poly1305 dispatcher takes the address of the
        # global poly1305_blocks_sve2 symbol with direct ADRP/ADD relocations.
        # Android shared-library links reject those relocations because the
        # symbol is preemptible, even when CMake's PIC option is enabled.
        # Keep ASM enabled on the other supported targets, but retain the
        # portable C implementation for Android ARM64 until the upstream SVE2
        # assembly marks the symbol hidden or uses a PIC-safe address sequence.
        if [ "$ABI" == "arm64-v8a" ]; then
            DEFINES="${DEFINES} -DOPENSSL_ASM=OFF -DOPENSSL_NO_ASM=ON"
        fi

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"
        echo "building $TYPE | $PLATFORM"
        echo "--------------------"
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"
        DEFINES="${DEFINES} \
            -DNO_FORK=ON \
            -DOPENSSL_OCSP=OFF \
            -DOPENSSL_CMP=OFF \
            "
        rm -f CMakeCache.txt *.a *.o
        DEFINES="${DEFINES} -DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF"
        cmake .. \
            ${DEFINES} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/android.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
            -DBUILD_TESTING=OFF \
            -DANDROID_ABI=${ABI} \
            -DANDROID_API=${ANDROID_API} \
            -DANDROID_TOOLCHAIN=clang \
            -DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_IGNORE_PATH=/opt/homebrew \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DPLATFORM=$PLATFORM \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DENABLE_VISIBILITY=OFF
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd "Release/lib/"
        mkdir -p crypto
        mkdir -p ssl
        mv libcrypto.a crypto/libcrypto.a
        mv libssl.a ssl/libssl.a
        cd crypto
        ar -x libcrypto.a
        for f in *.o; do mv "$f" "openssl_${ARCH}_crypto_$f"; done
        for obj in *.o; do
            if [ -z "$(nm "$obj")" ]; then
                echo "Removing empty object file: $obj"
                rm -f "$obj"
            fi
        done
        ar rcs "../libcrypto.a" openssl_${ARCH}_crypto_*.o
        cd ../ssl
        ar -x libssl.a
        for f in *.o; do mv "$f" "openssl_${ARCH}_ssl_$f"; done
         for obj in *.o; do
            if [ -z "$(nm "$obj")" ]; then
                echo "Removing empty object file: $obj"
                rm -f "$obj"
            fi
        done
        ar rcs "../libssl.a" openssl_${ARCH}_ssl_*.o
        cd ..
        rm -rf crypto ssl
        cd ..

    elif [ "$TYPE" == "vs" ]; then

        echo "building openssl $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        pwd
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -rf "build_${TYPE}_${ARCH}"
        fi

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        # Always disable ASM for VS static OF builds.
        # The VS static build fails without a complete NASM/MASM pipeline under
        # openssl-cmake 4.x; keep one ASM-disabled path for every VS architecture.
        DEFINES="${DEFINES} -DOPENSSL_ASM=OFF -DOPENSSL_NO_ASM=ON"

        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        rm -f CMakeCache.txt *.a *.o *.lib
        DEFINES="${DEFINES} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"

        cmake .. \
            ${DEFINES} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DZLIB_INCLUDE_DIRS=${ZLIB_INCLUDE_DIR} \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INSTALL_INCLUDEDIR=include \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            ${CMAKE_WIN_SDK} \
            -DOPENSSL_TARGET_ARCH=$BUILD_PLATFORM \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"

        cmake --build . --config Release -j${PARALLEL_MAKE} --target install

        cd ..

    elif [ "$TYPE" == "linux" ]; then

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"
        echo "building $TYPE | $PLATFORM"

        if [ $CROSSCOMPILING -eq 1 ]; then
            source $APOTHECARY_DIR/configure/${TYPE}${PLATFORM}_configure.sh
        fi
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"

        DEFINES="${DEFINES} \
            -DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=${C_STANDARD} \
            -DCMAKE_CXX_STANDARD=${CPP_STANDARD} \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"
        cmake .. ${DEFINES} \
            -DPLATFORM=$PLATFORM \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
            -DCMAKE_MINIMUM_REQUIRED_VERSION=3.22 \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_SYSTEM_PROCESSOR=$ABI \
            -DGCC_VERSION=${GCC_VERSION} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/${TYPE}${PLATFORM}.toolchain.cmake \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_IGNORE_PATH=${TOOLCHAIN_ROOT}/lib \
            -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY}
        cmake --build . --config Release -j${PARALLEL_MAKE} --target install
        cd ..

    else
        echoWarning "TODO: build $TYPE lib"
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
    . "$SECURE_SCRIPT"
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|linux)$ ]]; then

        BUILD_SUBDIR="build_${TYPE}_${PLATFORM}"
        if [ "$TYPE" == "catos" ]; then
            BUILD_SUBDIR="${BUILD_SUBDIR}_${ARCH}"
        fi
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        echo "copy: ${BUILD_SUBDIR}/Release/lib/libcrypto.a"
        cp -v "${BUILD_SUBDIR}/Release/lib/libcrypto.a" $1/lib/$TYPE/$PLATFORM/libcrypto.a
        cp -v "${BUILD_SUBDIR}/Release/lib/libssl.a" $1/lib/$TYPE/$PLATFORM/libssl.a
        cp -Rv "${BUILD_SUBDIR}/Release/include" $1/

        secure "$1/lib/$TYPE/$PLATFORM/libssl.a" "openssl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        secure "$1/lib/$TYPE/$PLATFORM/libcrypto.a" "crypto.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "${BUILD_SUBDIR}/Release/lib/pkgconfig/openssl.pc" $1/lib/$TYPE/$PLATFORM/openssl.pc
        cp -vR "${BUILD_SUBDIR}/Release/lib/pkgconfig/libcrypto.pc" $1/lib/$TYPE/$PLATFORM/libcrypto.pc
        cp -vR "${BUILD_SUBDIR}/Release/lib/pkgconfig/libssl.pc" $1/lib/$TYPE/$PLATFORM/libssl.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/openssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libcrypto.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "vs" ]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        FILE_POSTFIX=-x64
        if [ ${ARCH} == "32" ]; then
            FILE_POSTFIX=""
        fi
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/
        cp -f "build_${TYPE}_${ARCH}/Release/lib/libcrypto.lib" $1/lib/$TYPE/$PLATFORM/libcrypto.lib
        cp -f "build_${TYPE}_${ARCH}/Release/lib/libssl.lib" $1/lib/$TYPE/$PLATFORM/libssl.lib

        cp -Rv "build_${TYPE}_${ARCH}/Release/lib/cmake" "$1/lib/$TYPE/$PLATFORM/cmake/"

        secure "$1/lib/$TYPE/$PLATFORM/libssl.lib" "openssl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        secure "$1/lib/$TYPE/$PLATFORM/libcrypto.lib" "crypto.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${ARCH}/Release/lib/pkgconfig/openssl.pc" $1/lib/$TYPE/$PLATFORM/openssl.pc
        cp -vR "build_${TYPE}_${ARCH}/Release/lib/pkgconfig/libcrypto.pc" $1/lib/$TYPE/$PLATFORM/libcrypto.pc
        cp -vR "build_${TYPE}_${ARCH}/Release/lib/pkgconfig/libssl.pc" $1/lib/$TYPE/$PLATFORM/libssl.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/openssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libcrypto.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:${1}/lib/$TYPE/$PLATFORM"

    elif [ "$TYPE" == "android" ]; then
        mkdir -p $1/include
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        echo "cppy: build_${TYPE}_${PLATFORM}/Release/lib/libcrypto.a"
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcrypto.a" $1/lib/$TYPE/$PLATFORM/libcrypto.a
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libssl.a" $1/lib/$TYPE/$PLATFORM/libssl.a

        cp -Rv "build_${TYPE}_${PLATFORM}/Release/lib/cmake" "$1/lib/$TYPE/$PLATFORM/cmake/"

        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/

        secure "$1/lib/$TYPE/$PLATFORM/libssl.a" "openssl.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
        secure "$1/lib/$TYPE/$PLATFORM/libcrypto.a" "crypto.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"

        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/openssl.pc" $1/lib/$TYPE/$PLATFORM/openssl.pc
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libcrypto.pc" $1/lib/$TYPE/$PLATFORM/libcrypto.pc
        cp -vR "build_${TYPE}_${PLATFORM}/Release/lib/pkgconfig/libssl.pc" $1/lib/$TYPE/$PLATFORM/libssl.pc

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/openssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libcrypto.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        PKG_FILE="$1/lib/$TYPE/$PLATFORM/libssl.pc"
        sed -i.bak "s|^prefix=.*|prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^exec_prefix=.*|exec_prefix=${1}|" "$PKG_FILE"
        sed -i.bak "s|^libdir=.*|libdir=${1}/lib/${TYPE}/${PLATFORM}/|" "$PKG_FILE"
        sed -i.bak "s|^includedir=.*|includedir=${1}/include|" "$PKG_FILE"
        rm -v "$PKG_FILE.bak"

        export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}:$1/lib/$TYPE/$PLATFORM"
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

    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos|emscripten|linux)$ ]]; then
        BUILD_SUBDIR="build_${TYPE}_${PLATFORM}"
        if [ "$TYPE" == "catos" ]; then
            BUILD_SUBDIR="${BUILD_SUBDIR}_${ARCH}"
        fi
        if [ -d "$BUILD_SUBDIR" ]; then
            rm -r "$BUILD_SUBDIR"
        fi
    elif [ "$TYPE" == "vs" ]; then
        if [ -d "build_${TYPE}_${ARCH}" ]; then
            rm -r build_${TYPE}_${ARCH}
        fi
    elif [ "$TYPE" == "android" ]; then
        if [ -d "build_${TYPE}_${ABI}" ]; then
            rm -r build_${TYPE}_${ABI}
        fi
    else
        echoWarning "TODO: clean $TYPE lib"
        make clean
    fi
}

function save() {
    . "$SAVE_SCRIPT"
    savestatus ${TYPE} "openssl" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "openssl" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
