#!/usr/bin/env bash
#
# Poco
# C++ with Batteries Included
# http://pocoproject.org/
#
# uses an autotools build system,
# specify specfic build configs in poco/config using ./configure --config=NAME

# define the version
VER=1.12.5p2-release

# tools for git use
GIT_URL=https://github.com/pocoproject/poco
GIT_TAG=poco-${VER}

FORMULA_TYPES=( "osx" "vs" "ios" "watchos" "catos" "xros" "tvos" )

#dependencies
FORMULA_DEPENDS=( "openssl" )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
FORMULA_DEPENDS_MANUAL=1

# For Poco Builds, we omit both Data/MySQL and Data/ODBC because they require
# 3rd Party libraries.  See https://github.com/pocoproject/poco/blob/develop/README
# for more information.

SHA=

# download the source code and unpack it into LIB_NAME
function download() {
    if [ "$SHA" == "" ] ; then
        echo "SHA=="" Using $GIT_URL with GIT_TAG=$GIT_TAG"
        curl -Lk $GIT_URL/archive/$GIT_TAG.tar.gz -o poco-$GIT_TAG.tar.gz
        tar -xf poco-$GIT_TAG.tar.gz
        mv poco-$GIT_TAG poco
        rm poco*.tar.gz
    else
        echo "$GIT_URL - Using SHA=$SHA"
        git clone $GIT_URL -b poco-$VER
    fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {

    if [ "$SHA" != "" ] ; then
        echo "Setting git repo to SHA=$SHA"
        git reset --hard $SHA
    fi

    if [ "$TYPE" != "linux" ] && [ "$TYPE" != "ios" ] && [ "$TYPE" != "tvos" ] && [ $FORMULA_DEPENDS_MANUAL -ne 1 ]; then
        # manually prepare dependencies
        apothecaryDependencies download
        apothecaryDependencies prepare
        # Build and copy all dependencies in preparation
        apothecaryDepend build openssl
        apothecaryDepend copy openssl
    fi

    # make backups of the ios config files since we need to edit them
    if [[ "$TYPE" == "ios" ||  "$TYPE" == "tvos" ]] ; then
        mkdir -p lib/$TYPE
        mkdir -p lib/iPhoneOS

        if [[ "$TYPE" == "tvos" ]]; then
            cp $FORMULA_DIR/AppleTV build/config/AppleTV
            cp $FORMULA_DIR/AppleTVSimulator build/config/AppleTVSimulator
        fi

        # fix using sed i686 reference and allow overloading variable
        sed -i "" "s|POCO_TARGET_OSARCH.* = .*|POCO_TARGET_OSARCH ?= x86_64|" build/config/iPhoneSimulator-clang-libc++
        sed -i "" "s|OSFLAGS            = -arch|OSFLAGS            ?= -arch arm64 -arch|" build/config/iPhoneSimulator-clang-libc++
        sed -i "" "s|STATICOPT_CC    =|STATICOPT_CC    ?= -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|STATICOPT_CXX   =|STATICOPT_CXX   ?= -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|OSFLAGS                 = -arch|OSFLAGS                ?= -arch|" build/config/iPhone
        sed -i "" "s|RELEASEOPT_CC   = -DNDEBUG -O2|RELEASEOPT_CC   =  -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|RELEASEOPT_CXX  = -DNDEBUG -O |RELEASEOPT_CXX  =  -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone

        # sed -i .tmp "s|EVP_CIPHER_CTX_cleanup(_pContext);||g" Crypto/src/CipherImpl.cpp
        # sed -i -e "s|#include <openssl/evp.h>|#include <openssl/evp.h>\n#include <openssl/bn.h>|" Crypto/src/X509Certificate.cpp

        # cp build/rules/compile build/rules/compile.orig
        # Fix for making debug and release, making just release
        sed -i "" "s|all_static: static_debug static_release|all_static: static_release|" build/rules/compile


    elif [ "$TYPE" == "vs" ] ; then
      
        apothecaryDepend prepare zlib
        apothecaryDepend build zlib
        apothecaryDepend copy zlib  

        apothecaryDepend prepare openssl
        apothecaryDepend build openssl
        apothecaryDepend copy openssl  

    elif [ "$TYPE" == "android" ] ; then
        installAndroidToolchain
        if patch -p0 -u -N --dry-run --silent < $FORMULA_DIR/android.patch 2>/dev/null ; then
            patch -p0 -u < $FORMULA_DIR/android.patch
        fi
        cp $FORMULA_DIR/Android build/config/Android
    elif [ "$TYPE" == "linux" -o "$TYPE" == "linux64" ] ; then
        cp $FORMULA_DIR/Linux build/config/Linux
    fi

}

# executed inside the lib src dir
function build() {
    LIBS_ROOT=$(realpath $LIBS_DIR)
    local BUILD_OPTS="--no-tests --no-samples --static --omit=CppUnit,CppUnit/WinTestRunner,Data,Data/SQLite,Data/ODBC,Data/MySQL,PageCompiler,PageCompiler/File2Page,CppParser,PDF,PocoDoc,ProGen,MongoDB"
    if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
        BUILD_OPTS="-DPOCO_STATIC=YES -DENABLE_DATA=OFF -DENABLE_DATA_SQLITE=OFFF -DENABLE_DATA_ODBC=OFF -DENABLE_DATA_MYSQL=OFF -DENABLE_PAGECOMPILER=OFF -DENABLE_PAGECOMPILER_FILE2PAGE=OFF -DENABLE_MONGODB=OFF"
       
        mkdir -p "build_${TYPE}_${PLATFORM}"
        cd "build_${TYPE}_${PLATFORM}"

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.a"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"              
        cmake .. ${DEFS} \
            ${BUILD_OPTS} \
            -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
            -DPLATFORM=$PLATFORM \
            -DENABLE_BITCODE=OFF \
            -DENABLE_ARC=OFF \
            -DENABLE_VISIBILITY=OFF \
            -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DOPENSSL_USE_STATIC_LIBS=YES 
        cmake --build . --config Release --target install
        cd ..


    elif [ "$TYPE" == "vs" ] ; then

        BUILD_OPTS="-DPOCO_STATIC=YES -DENABLE_DATA=OFF -DENABLE_DATA_SQLITE=OFFF -DENABLE_DATA_ODBC=OFF -DENABLE_DATA_MYSQL=OFF -DENABLE_PAGECOMPILER=OFF -DENABLE_PAGECOMPILER_FILE2PAGE=OFF -DENABLE_MONGODB=OFF"
       
          
        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
        local OF_LIBS_OPENSSL_ABS_PATH=`realpath $OF_LIBS_OPENSSL`

        export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
        export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM
        export OPENSSL_WINDOWS_PATH=$(cygpath -w ${OF_LIBS_OPENSSL_ABS_PATH} | sed "s/\\\/\\\\\\\\/g")

        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libssl.lib ${OPENSSL_PATH}/lib/libssl.lib # this works! 
        cp ${OPENSSL_PATH}/lib/${TYPE}/${PLATFORM}/libcrypto.lib ${OPENSSL_PATH}/lib/libcrypto.lib
            
        echo "building poco $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"

        LIBS_ROOT=$(realpath $LIBS_DIR)

        ZLIB_ROOT="$LIBS_ROOT/zlib/"
        ZLIB_INCLUDE_DIR="$LIBS_ROOT/zlib/include"
        ZLIB_LIBRARY="$LIBS_ROOT/zlib/lib/$TYPE/$PLATFORM/zlib.lib"

        DEFS="-DLIBRARY_SUFFIX=${ARCH} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_STANDARD=17 \
            -DCMAKE_CXX_STANDARD=17 \
            -DCMAKE_CXX_STANDARD_REQUIRED=ON \
            -DCMAKE_CXX_EXTENSIONS=OFF
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_INSTALL_PREFIX=Release \
            -DCMAKE_INCLUDE_OUTPUT_DIRECTORY=include \
            -DCMAKE_INSTALL_INCLUDEDIR=include"              
        cmake .. ${DEFS} \
            ${BUILD_OPTS} \
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DCURL_USE_OPENSSL=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DZLIB_ROOT=${ZLIB_ROOT} \
            -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIR} \
            -DZLIB_LIBRARY=${ZLIB_LIBRARY} \
            -DCMAKE_VERBOSE_MAKEFILE=${VERBOSE_MAKEFILE} \
            ${CMAKE_WIN_SDK} \
            -DOPENSSL_USE_STATIC_LIBS=YES \
            -DOPENSSL_ROOT_DIR="$OF_LIBS_OPENSSL_ABS_PATH" \
            -DOPENSSL_INCLUDE_DIR="$OF_LIBS_OPENSSL_ABS_PATH/include" \
            -DOPENSSL_LIBRARIES="$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM/libcrypto.lib;$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE/$PLATFORM/libssl.lib;" \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"
        cmake --build . --config Release --target install
        cd ..

        rm ${OPENSSL_PATH}/lib/libssl.lib
        rm ${OPENSSL_PATH}/lib/libcrypto.lib

    elif [ "$TYPE" == "android" ] ; then
        BUILD_OPTS="-DPOCO_STATIC=YES -DENABLE_DATA=OFF -DENABLE_DATA_SQLITE=OFFF -DENABLE_DATA_ODBC=OFF -DENABLE_DATA_MYSQL=OFF -DENABLE_PAGECOMPILER=OFF -DENABLE_PAGECOMPILER_FILE2PAGE=OFF -DENABLE_MONGODB=OFF"
        OPENSSL_OPTS="-DOPENSSL_USE_STATIC_LIBS=YES -DOPENSSL_ROOT_DIR=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local -DOPENSSL_INCLUDE_DIR=${BUILD_DIR}/openssl/include -DOPENSSL_LIBRARIES=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/ -DOPENSSL_CRYPTO_LIBRARY=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/libssl.a"

        mkdir -p build_$ABI
        cd build_$ABI
        cmake -G 'Unix Makefiles' -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" $BUILD_OPTS -DANDROID_ABI=$ABI -DCMAKE_C_FLAGS_RELEASE="-g0 -O3" -DCMAKE_CXX_FLAGS_RELEASE="-g0 -O3" -DCMAKE_BUILD_TYPE=RELEASE $OPENSSL_OPTS ..
        make -j${PARALLEL_MAKE} VERBOSE=1

    elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] ; then
        ./configure $BUILD_OPTS
        make -j${PARALLEL_MAKE}
        # delete debug builds
        rm -f lib/Linux/$(uname -m)/*d.a
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ] || [ "$TYPE" == "linuxaarch64" ]; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export CROSS_COMPILE=$TOOLCHAIN_ROOT/bin/$TOOLCHAIN_PREFIX-
            export LIBRARY_PATH="$SYSROOT/usr/lib $SYSROOT/usr/lib/$TOOLCHAIN_PREFIX"
        fi
        ./configure $BUILD_OPTS \
            --library-path="$LIBRARY_PATH" \
            --cflags="$CFLAGS" \
            --prefix=$BUILD_DIR/poco/install/$TYPE
        make -j${PARALLEL_MAKE}
        make install
        # delete debug builds
        rm -f install/$TYPE/lib/*d.a
    else
        echoWarning "TODO: build $TYPE lib"
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -pv $1/include/Poco
    cp -Rv Crypto/include/Poco/Crypto $1/include/Poco
    cp -Rv Data/include/Poco/Data $1/include/Poco
    cp -Rv Data/SQLite/include/Poco/Data $1/include/Poco
    cp -Rv Foundation/include/Poco/* $1/include/Poco
    cp -Rv JSON/include/Poco/JSON $1/include/Poco
    cp -Rv MongoDB/include/Poco/MongoDB $1/include/Poco
    cp -Rv Net/include/Poco/Net $1/include/Poco
    cp -Rv NetSSL_OpenSSL/include/Poco/Net/* $1/include/Poco/Net
    cp -Rv SevenZip/include/Poco/SevenZip $1/include/Poco
    cp -Rv Util/include/Poco/Util $1/include/Poco
    cp -Rv XML/include/Poco/* $1/include/Poco
    cp -Rv Zip/include/Poco/Zip $1/include/Poco

    rm -rf $1/lib/$TYPE
    mkdir -p $1/lib/$TYPE

	# libs
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${PLATFORM}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${PLATFORM}/Release/lib/"*.a $1/lib/$TYPE/$PLATFORM/
	elif [ "$TYPE" == "vs" ] ; then
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -v "build_${TYPE}_${ARCH}/Release/lib/"*.lib $1/lib/$TYPE/$PLATFORM/
        # poco needs some dlls 
        cp -v "build_${TYPE}_${ARCH}/Release/bin/"*.dll $1/lib/$TYPE/$PLATFORM/ 
	elif [ "$TYPE" == "msys2" ] ; then
		cp -vf lib/MinGW/i686/*.a $1/lib/$TYPE
		#cp -vf lib/MinGW/x86_64/*.a $1/lib/$TYPE
	elif [ "$TYPE" == "linux" ] ; then
		cp -v lib/Linux/$(uname -m)/*.a $1/lib/$TYPE
	elif [ "$TYPE" == "linux64" ] ; then
		cp -v lib/Linux/x86_64/*.a $1/lib/$TYPE
	elif [ "$TYPE" == "linuxarmv6l" ] ; then
		cp -v install/$TYPE/lib/*.a $1/lib/$TYPE
	elif [ "$TYPE" == "linuxarmv7l" ] ; then
		cp -v install/$TYPE/lib/*.a $1/lib/$TYPE
	elif [ "$TYPE" == "android" ] ; then
		rm -rf $1/lib/$TYPE/$ABI
		mkdir -p $1/lib/$TYPE/$ABI
		cp -v build_$ABI/lib/*.a $1/lib/$TYPE/$ABI
	else
		echoWarning "TODO: copy $TYPE lib"
	fi

	# copy license file
	echo "remove license"
	if [ -d "$1/license" ]; then
        rm -rf $1/license
    fi
	echo "create license dir"
	mkdir -p $1/license
	echo "copy license"
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
	else
		make clean
	fi
}

function save() {
    . "$SAVE_SCRIPT" 
    savestatus ${TYPE} "poco" ${ARCH} ${VER} true "${SAVE_FILE}"
}

function load() {
    . "$LOAD_SCRIPT"
    if loadsave ${TYPE} "poco" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}

