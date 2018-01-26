#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" )

#dependencies
FORMULA_DEPENDS=( "openssl" )

# define the version by sha
VER=7_53_1

# tools for git use
GIT_URL=https://github.com/curl/curl.git
GIT_TAG=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	curl -Lk https://github.com/curl/curl/archive/curl-$VER.tar.gz -o curl-$VER.tar.gz
	tar -xf curl-$VER.tar.gz
	mv curl-curl-$VER curl
	rm curl*.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "vs" ] ; then
		cp $FORMULA_DIR/build-openssl.bat projects/build-openssl.bat
	fi
}

# executed inside the lib src dir
function build() {
	local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		local OF_LIBS_OPENSSL_ABS_PATH=$(realpath ../openssl)
		export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
		export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/
		PATH=$OPENSSL_LIBRARIES:$PATH cmd //c "projects\\generate.bat vc14"
		cd projects/Windows/VC14/lib

        # perform upgrade for vs2017, as project file will be for vs 2015
        if [ $VS_VER -gt 14 ] ; then
            vs-upgrade libcurl.sln
        fi

        if [ $ARCH == 32 ] ; then
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|Win32"
        else
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|x64"
        fi

	elif [ "$TYPE" == "android" ]; then
        perl -pi -e 's/HAVE_GLIBC_STRERROR_R/#HAVE_GLIBC_STRERROR_R/g' CMakeLists.txt
        perl -pi -e 's/HAVE_POSIX_STRERROR_R/#HAVE_POSIX_STRERROR_R/g' CMakeLists.txt

        mkdir -p build_$ABI
        cd build_$ABI

        OPENSSL_OPTS="-DOPENSSL_USE_STATIC_LIBS=YES -DOPENSSL_ROOT_DIR=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local -DOPENSSL_INCLUDE_DIR=${BUILD_DIR}/openssl/include -DOPENSSL_LIBRARIES=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/ -DOPENSSL_CRYPTO_LIBRARY=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/libcrypto.a -DOPENSSL_SSL_LIBRARY=${BUILD_DIR}/openssl/build_$ABI/inst/usr/local/lib/libssl.a"

        cmake -C "$FORMULA_DIR/tryrun.cmake" -G 'Unix Makefiles' -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" -DANDROID_ABI=$ABI -DHAVE_POSIX_STRERROR_R=1 -DSIZEOF_SIZE_T=__SIZEOF_SIZE_T__ -DCURL_STATICLIB=ON $OPENSSL_OPTS ..
        make -j${PARALLEL_MAKE} libcurl VERBOSE=1
        cd ..

	elif [ "$TYPE" == "osx" ]; then
        #local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf

        export CFLAGS="-arch i386 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch i386 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		./configure \
            --with-darwinssl \
            --prefix=$BUILD_DIR/curl/build/osx/x86 \
            --enable-static \
            --disable-shared \
            --host=x86-apple-darwin
        make clean
	    make -j${PARALLEL_MAKE}
        make install

        export CFLAGS="-arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
        export LDFLAGS="-arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		./configure \
            --with-darwinssl \
            --prefix=$BUILD_DIR/curl/build/osx/x64 \
            --enable-static \
            --disable-shared \
            --host=x86_64-apple-darwin
        make clean
	    make -j${PARALLEL_MAKE}
        make install

        cp -r build/osx/x64/* build/osx/

        lipo -create build/osx/x86/lib/libcurl.a \
                     build/osx/x64/lib/libcurl.a \
                    -output build/osx/lib/libcurl.a
	    make install
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        ./buildconf
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="i386 x86_64 armv7 arm64" #armv7s
        fi
		for IOS_ARCH in ${IOS_ARCHS}; do
            echo
            echo
            echo "Compiling for $IOS_ARCH"
    	    source ../../ios_configure.sh $TYPE $IOS_ARCH
            ./configure \
                --with-darwinssl \
                --prefix=$BUILD_DIR/curl/build/$TYPE/${IOS_ARCH} \
                --enable-static \
                --disable-shared \
                --disable-ntlm-wb \
                --host=$HOST \
                --target=$HOST \
                --enable-threaded-resolver \
                --enable-ipv6
            #make clean
            make -j${PARALLEL_MAKE}
            make install
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "$TYPE" == "ios" ]; then
            lipo -create build/$TYPE/i386/lib/libcurl.a \
                         build/$TYPE/x86_64/lib/libcurl.a \
                         build/$TYPE/armv7/lib/libcurl.a \
                         build/$TYPE/arm64/lib/libcurl.a \
                        -output build/$TYPE/lib/libcurl.a
        elif [ "$TYPE" == "tvos" ]; then
            lipo -create build/$TYPE/x86_64/lib/libcurl.a \
                         build/$TYPE/arm64/lib/libcurl.a \
                        -output build/$TYPE/lib/libcurl.a
        fi
    else
        echo "building other for $TYPE"
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export LDFLAGS=-L$SYSROOT/usr/lib
            export CFLAGS=-I$SYSROOT/usr/include
        fi

        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        ./buildconf
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
		./configure --with-ssl=$OPENSSL_DIR --enable-static --disable-shared
        make clean
	    make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/curl

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	# Standard *nix style copy.
	# copy headers
	cp -Rv include/curl/* $1/include/curl/

	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v "build/Win32/VC14/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/Win32/libcurl.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v "build/Win64/VC14/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/x64/libcurl.lib
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv build/$TYPE/lib/libcurl.a $1/lib/$TYPE/curl.a
	elif [ "$TYPE" == "android" ] ; then
        #mkdir -p $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
        cp -Rv build_$ABI/lib/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
	fi

    if [ "$TYPE" == "osx" ]; then
        cp build/$TYPE/x86/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
        cp build/$TYPE/x64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    elif [ "$TYPE" == "ios" ]; then
        cp build/$TYPE/i386/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
        cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    elif [ "$TYPE" == "tvos" ]; then
        cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    elif [ "$TYPE" == "vs" ]; then
		if [ $ARCH == 32 ] ; then
            cp include/curl/curlbuild.h $1/include/curl/curlbuild32.h
        else
            cp include/curl/curlbuild.h $1/include/curl/curlbuild64.h
        fi
    elif [ "$TYPE" == "android" ]; then
		cp build_$ABI/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
    fi

cat > $1/include/curl/curlbuild.h << EOF
/* The size of long, as computed by sizeof. */
#if defined(__LP64__) || defined(_WIN64)
#include "curl/curlbuild64.h"
#else
#include "curl/curlbuild32.h"
#endif
EOF

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v COPYING $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
	else
		make clean
	fi
}
