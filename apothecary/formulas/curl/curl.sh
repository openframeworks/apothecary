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
VER=7_59_0

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
	if [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        # apply https://github.com/curl/curl/commit/b7b2809a212a69f1ce59a25ba86b4f1d8a17ebc4
		patch -p0 -u < $FORMULA_DIR/b7b2809a212a69f1ce59a25ba86b4f1d8a17ebc4.patch
	fi
}

# executed inside the lib src dir
function build() {
	local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		local OF_LIBS_OPENSSL_ABS_PATH=`realpath $OF_LIBS_OPENSSL`
		export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
		export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/
		export OPENSSL_WINDOWS_PATH=$(cygpath -w ${OF_LIBS_OPENSSL_ABS_PATH} | sed "s/\\\/\\\\\\\\/g")
	
        cd projects
        
        #hardcoded to vc14 ( VS 2017 ) as there is now VS 2019 project file option 
  		cmd //c "generate.bat vc14"
		cd Windows/VC14/lib
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.vcxproj
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.vcxproj.filters
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.sln

        # /p:PlatformToolset=v142 is a sort of hack to retarget solution to VS 2019 when the sln doesn't support the platform
        if [ $ARCH == 32 ] ; then
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln "Build /p:PlatformToolset=v142" "LIB Release - LIB OpenSSL|Win32"
        elif [ $ARCH == 64 ] ; then
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln "Build /p:PlatformToolset=v142" "LIB Release - LIB OpenSSL|x64"
        elif [ $ARCH == "ARM" ] ; then
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln "Build /p:PlatformToolset=v142" "LIB Release - LIB OpenSSL|ARM"
        fi

	elif [ "$TYPE" == "android" ]; then
	    local BUILD_TO_DIR=$BUILD_DIR/curl/build/$TYPE/$ABI
        local OPENSSL_DIR=$BUILD_DIR/openssl/
	    source ../../android_configure.sh $ABI

	    if [ "$ARCH" == "armv7" ]; then
            export HOST=armv7a-linux-android
        elif [ "$ARCH" == "arm64" ]; then
            export HOST=aarch64-linux-android
        elif [ "$ARCH" == "x86" ]; then
            export HOST=x86-linux-android
        fi
        ./buildconf
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD
	    ./configure --prefix=$BUILD_TO_DIR --host=$HOST --with-ssl=$OPENSSL_DIR --target=$HOST \
            --enable-static \
            --disable-shared \
            --disable-verbose \
            --enable-threaded-resolver \
            --enable-libgcc \
            --enable-ipv6

        sed -i "s/#define HAVE_GETPWUID_R 1/\/\* #undef HAVE_GETPWUID_R \*\//g" lib/curl_config.h
        make clean
	    make -j${PARALLEL_MAKE}
	    make install
	elif [ "$TYPE" == "osx" ]; then
        
        local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        ./buildconf
                
        export CFLAGS="-arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot${SDK_PATH}"
        export LDFLAGS="-arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot${SDK_PATH}"
        ./configure \
            --with-secure-transport \
			--with-ssl=$OPENSSL_DIR \
			--without-brotli \
            --prefix=$BUILD_DIR/curl/build/osx/x64 \
            --enable-static \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-shared \
            --disable-ldap \
            --disable-ldaps \
            --host=x86_64-apple-darwin
        make clean
        make -j${PARALLEL_MAKE}
        make install

        export CFLAGS="-arch arm64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot${SDK_PATH}"
        export LDFLAGS="-arch arm64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot${SDK_PATH}"
		./configure \
            --with-secure-transport \
            --with-ssl=$OPENSSL_DIR \
			--without-brotli \
            --prefix=$BUILD_DIR/curl/build/osx/arm64 \
            --enable-static \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-shared \
            --disable-ldap \
            --disable-ldaps \
            --host=arm-apple-darwin
        make clean
	    make -j${PARALLEL_MAKE}
        make install

        cp -r build/osx/x64/* build/osx/

        lipo -create build/osx/arm64/lib/libcurl.a \
                     build/osx/x64/lib/libcurl.a \
                    -output build/osx/lib/libcurl.a
	    make install
	elif [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
        ./buildconf
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
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
            
            # solution from this issue: https://github.com/curl/curl/issues/3189
            # force config to see stuff that is there
            printf '%s\n' '#ifndef HAVE_SOCKET' '#define HAVE_SOCKET  1' '#endif' '#ifndef HAVE_FCNTL_O_NONBLOCK' '#define HAVE_FCNTL_O_NONBLOCK 1' '#endif' >> lib/curl_config.h
            
            make -j${PARALLEL_MAKE}
            make install
        done

        cp -r build/$TYPE/arm64/* build/$TYPE/

        if [ "$TYPE" == "ios" ]; then
            lipo -create build/$TYPE/x86_64/lib/libcurl.a \
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
        elif [ $ARCH == "ARM" ] ; then
			mkdir -p $1/lib/$TYPE/ARM
			cp -v "build/Win64/VC14/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/ARM/libcurl.lib
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv build/$TYPE/lib/libcurl.a $1/lib/$TYPE/curl.a
	elif [ "$TYPE" == "android" ] ; then
	    mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
		cp -Rv build/$TYPE/$ABI/lib/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
	fi

    # if [ "$TYPE" == "osx" ]; then
    #     cp build/$TYPE/x86/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
    #     cp build/$TYPE/x64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    # elif [ "$TYPE" == "ios" ]; then
    #     cp build/$TYPE/i386/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
    #     cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    # elif [ "$TYPE" == "tvos" ]; then
    #     cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    # elif [ "$TYPE" == "vs" ]; then
		# if [ $ARCH == 32 ] ; then
    #         cp include/curl/curlbuild.h $1/include/curl/curlbuild32.h
    #     else
    #         cp include/curl/curlbuild.h $1/include/curl/curlbuild64.h
    #     fi
    # elif [ "$TYPE" == "android" ]; then
		# 		cp include/curl/curlbuild.h $1/include/curl/curlbuild32.h
    # fi

# cat > $1/include/curl/curlbuild.h << EOF
# /* The size of long, as computed by sizeof. */
# #if defined(__LP64__) || defined(_WIN64)
# #include "curl/curlbuild64.h"
# #else
# #include "curl/curlbuild32.h"
# #endif
# EOF

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
