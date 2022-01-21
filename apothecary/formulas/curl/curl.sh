#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" "ios" "tvos")

# Android to implementation 'com.android.ndk.thirdparty:curl:7.79.1-beta-1'

#dependencies
FORMULA_DEPENDS=( 
    # "openssl" 
    )

# define the version by sha
VER=7_81_0
VER_D=7.81.0
SHA1=b89d75e6202d3ce618eaf5d9deef75dd00f55e4b

# tools for git use
GIT_URL=https://github.com/curl/curl.git
GIT_TAG=$VER


# download the source code and unpack it into LIB_NAME
function download() {

    # if [ "$TYPE" == "android" ] ; then
   
    #     git clone https://github.com/robertying/openssl-curl-android.git

    #     mv openssl-curl-android curl 

       
    #     wget -nv https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/ci-release-5843a396/curl_7.68.0-android-arm64.zip
    #     unzip curl_7.68.0-android-arm64
    #     mv curl_7.68.0-android-arm64 curl 

    #     wget -nv https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/ci-release-5843a396/curl_7.68.0-android-arm64.zip
    #     unzip curl_7.68.0-android-arm64
    #     mv curl_$VER_D curl 
    #     # wget -nv https://curl.haxx.se/download/curl-7.74.0.tar.gz #wget a curl
    #     # https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/ci-release-5843a396/curl_7.68.0-ios-arm64.zip
    #else
        curl -Lk https://github.com/curl/curl/releases/download/curl-$VER/curl-$VER_D.tar.gz -o curl-$VER.tar.gz   
        tar -xf curl-$VER.tar.gz
        mv curl-$VER_D curl 
        # if [ "$CHECKSHA" != "$SHA1" ] ; then
        # echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
        # else
        #     echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
        # fi
        rm curl*.tar.gz
    #fi
    local CHECKSHA=$(shasum curl-$VER.tar.gz | awk '{print $1}')

   

	
	
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
    echo "prepare"
}

# executed inside the lib src dir
function build() {


    export OF_LIBS_OPENSSL_ABS_PATH=$(realpath ${LIBS_DIR}/)
	
	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
        local OF_LIBS_OPENSSL_ABS_PATH=`realpath $OF_LIBS_OPENSSL`

		export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH
		export OPENSSL_LIBRARIES=$OF_LIBS_OPENSSL_ABS_PATH/lib/
		export OPENSSL_WINDOWS_PATH=$(cygpath -w ${OF_LIBS_OPENSSL_ABS_PATH} | sed "s/\\\/\\\\\\\\/g")
		PATH=$OPENSSL_LIBRARIES:$PATH cmd //c "projects\\generate.bat vc$VS_VER"
		cd projects/Windows/VC$VS_VER/lib
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.vcxproj
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.vcxproj.filters
		sed -i "s/..\\\\..\\\\..\\\\..\\\\..\\\\openssl\\\\inc32/${OPENSSL_WINDOWS_PATH}\\\\include/g" libcurl.sln

        if [ $ARCH == 32 ] ; then
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|Win32"
        else
            PATH=$OPENSSL_LIBRARIES:$PATH vs-build libcurl.sln Build "LIB Release - LIB OpenSSL|x64"
        fi

	elif [ "$TYPE" == "android" ]; then

        source ../../android_configure.sh $ABI make
        # cd tools
        # export api=19
        # ./build-android-curl.sh arm
        # ./build-android-curl.sh arm

        export OPENSSL_PATH=$OF_LIBS_OPENSSL_ABS_PATH/openssl
        local BUILD_TO_DIR=$BUILD_DIR/curl/build/$TYPE/$ABI
        export OPENSSL_LIBRARIES=$OPENSSL_PATH/lib/$TYPE/$ABI

        if [ "$ARCH" == "armv7" ]; then
            export HOST=armv7a-linux-android
        elif [ "$ARCH" == "arm64" ]; then
            export HOST=aarch64-linux-android
        elif [ "$ARCH" == "x86" ]; then
            export HOST=x86-linux-android
        elif [ "$ARCH" == "x86_64" ]; then
            export HOST=x86_64-linux-android
        fi

        git submodule update --init --recursive
        

        export NDK=$ANDROID_PLATFORM # e.g. $HOME/Library/Android/sdk/ndk/22.1.7171670
        export HOST_TAG=$HOST_PLATFORM # e.g. darwin-x86_64, see https://developer.android.com/ndk/guides/other_build_systems#overview
        export MIN_SDK_VERSION=21 # or any version you want

        # chmod +x ./build.sh
        #./build.sh

        export SSL_DIR=$OPENSSL_LIBRARIES

        export OUTPUT_DIR=$OPENSSL_LIBRARIES


        mkdir -p build
        mkdir -p build/$TYPE
        mkdir -p build/$TYPE/$ABI
        # cd curl
        # autoreconf -fi

        export DESTDIR="$BUILD_TO_DIR"

        export CFLAGS=""
        export CPPFLAGS="-D__ANDROID_API__=${ANDROID_API}"
        export LIBS="-l${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libssl.a -l${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libcrypto.a "
        export LDFLAGS="-L${OPENSSL_PATH}/lib ${LDFLAGS}"


       

        PATH="${PATH};${OPENSSL_PATH}/lib/${TYPE}"

         ./configure \
            --prefix=$BUILD_TO_DIR \
            --host=$HOST \
            --with-openssl=$OPENSSL_PATH \
            --target=$HOST \
            --with-pic \
            --enable-static \
            --disable-shared \
            --disable-verbose \
            --disable-threaded-resolver \
            --enable-libgcc \
            --enable-ipv6 \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-ldap \
            --disable-ldaps 

        # sed -i "s/#define HAVE_GETPWUID_R 1/\/\* #undef HAVE_GETPWUID_R \*\//g" lib/curl_config.h
        make clean
        make -j${PARALLEL_MAKE}
        make install

        # ./configure --host=$TARGET_HOST \
        #     --target=$TARGET_HOST \
        #     --prefix="$PWD/build/$TYPE/$ABI" \
        #     --with-openssl=$SSL_DIR $ARGUMENTS

        #     make -j$CORES
        #     make install
        #     #make clean
            


        # chmod 777 buildconf
        # ./buildconf
        # wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD
        # wget -nv http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD

        # # CURL_ARGS="--with-ssl --with-zlib --disable-ftp --disable-gopher 
        # #     --disable-file --disable-imap --disable-ldap --disable-ldaps 
        # #     --disable-pop3 --disable-proxy --disable-rtsp --disable-smtp 
        # #     --disable-telnet --disable-tftp --without-gnutls --without-libidn 
        # #     --without-librtmp --disable-dict"

        
        # export PATH="$OPENSSL_LIBRARIES:$PATH"

        # #mkdir -p $OPENSSL_DIR/lib
        # #cp -Rv $OPENSSL_LIBRARIES/* $OPENSSL_DIR/lib/
        # #sed -i "/ac_cpp=/s/\$CPPFLAGS/\$CPPFLAGS -O2/" configure

        # # export PKG_CONFIG_PATH=$OPENSSL_ABS_PATH/lib/pkgconfig
        # # export LD_LIBRARY_PATH=$OPENSSL_ABS_PATH/lib/

        # export DESTDIR="$BUILD_TO_DIR"
        # export CPPFLAGS="-I${OPENSSL_PATH}/include $CPPFLAGS"
        # export LDFLAGS="-L${OPENSSL_PATH}/lib $LDFLAGS "
        # export LIBS="-l${OPENSSL_PATH}/lib/${TYPE}/${ABI}/libssl.a -l${OPENSSL_PATH}/lib/${TYPE}/${ABI}//libcrypto.a "

        # ./configure --prefix=$BUILD_TO_DIR --host=$HOST --with-ssl=$OPENSSL_PATH --target=$HOST \
        #     --enable-static \
        #     --disable-shared \
        #     --disable-verbose \
        #     --disable-threaded-resolver \
        #     --enable-libgcc \
        #     --enable-ipv6 \
        #     --without-nghttp2 \
        #     --without-libidn2 \
        #     --disable-ldap \
        #     --disable-ldaps 

        # # sed -i "s/#define HAVE_GETPWUID_R 1/\/\* #undef HAVE_GETPWUID_R \*\//g" lib/curl_config.h
        # make clean
        # make -j${PARALLEL_MAKE}
        # make install
        

        # ///

        
        
        # perl -pi -e 's/HAVE_GLIBC_STRERROR_R/#HAVE_GLIBC_STRERROR_R/g' CMakeLists.txt
        # perl -pi -e 's/HAVE_POSIX_STRERROR_R/#HAVE_POSIX_STRERROR_R/g' CMakeLists.txt

        # mkdir -p build_$ABI
        # cd build_$ABI

        # OPENSSL_OPTS="-DTHREADS_HAVE_PTHREAD_ARG=0 -DENABLE_THREADED_RESOLVER=0 -CMAKE_SHARED_LINKER_FLAGS -DOPENSSL_USE_STATIC_LIBS=YES -DOPENSSL_ROOT_DIR=${BUILD_DIR}/openssl -DOPENSSL_INCLUDE_DIR=${BUILD_DIR}/openssl/include -DOPENSSL_LIBRARIES=${BUILD_DIR}/openssl/lib/android/$ABI/ -DOPENSSL_CRYPTO_LIBRARY=${BUILD_DIR}/openssl/lib/android/$ABI/libcrypto.a -DOPENSSL_SSL_LIBRARY=${BUILD_DIR}/openssl/lib/android/$ABI/libssl.a"

        # cmake -C "$FORMULA_DIR/tryrun.cmake" -G 'Unix Makefiles' -DCMAKE_TOOLCHAIN_FILE="${NDK_ROOT}/build/cmake/android.toolchain.cmake" -DANDROID_ABI=$ABI -DHAVE_POSIX_STRERROR_R=1 -DSIZEOF_SIZE_T=__SIZEOF_SIZE_T__ -DCURL_STATICLIB=ON $OPENSSL_OPTS ..
        # # mkdir -p build_$ABI

        # # ./configure \
        # #     --with-darwinssl \
        # #     --prefix="$build_$ABI" \
        # #     --enable-static \
        # #     --without-nghttp2 \
        # #     --without-libidn2 \
        # #     --disable-shared \
        # #     --disable-pthreads \
        # #     --disable-ldap \
        # #     --disable-ldaps \
        # #     --host=x86_64-apple-darwin
        # # make clean
        # #make -j${PARALLEL_MAKE} libcurl VERBOSE=1
        # #make install
        # make -j${PARALLEL_MAKE} libcurl VERBOSE=1
        # cd ..

	elif [ "$TYPE" == "osx" ]; then
        #local OPENSSL_DIR=$BUILD_DIR/openssl/build/$TYPE
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
        #./buildconf
        local SDK_PATH_XCODE_X86=SDK_PATH;
        if [ -n "${GITHUB_ACTIONS-}" ]; then
            if [ "$GITHUB_ACTIONS" = true ]; then
                # this is because Xcode 11.4 and newer links curl with a symbol which isn't present on 10.14 and older
                # in the future we will need to remove this, but this will provide legacy compatiblity while Github Actions has Xcode 11
                # note: Xcode 11.3.1 should be okay too.
                SDK_PATH_XCODE_X86="/Applications/Xcode_11.2.1.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
                EXTRA_SYSROOT="-isysroot${SDK_PATH_XCODE_X86}"
            fi
        else 
            EXTRA_SYSROOT="-isysroot${SDK_PATH}"
        fi



        # export OPENSSL_MAIN=${OF_LIBS_OPENSSL_ABS_PATH}/openssl
        # export OPENSSL_PATH=${OPENSSL_MAIN}/lib/$TYPE/


        export ARCH=x86_64
        export SDK=macosx
        export DEPLOYMENT_TARGET=10.8



        export CFLAGS=" -arch $ARCH -m$SDK-version-min=$OSX_MIN_SDK_VER ${EXTRA_SYSROOT}"
        export LDFLAGS="-arch $ARCH -m$SDK-version-min=$OSX_MIN_SDK_VER ${EXTRA_SYSROOT}"

        # PATH="${PATH};${OPENSSL_MAIN}/lib/${TYPE}"

        # --with-openssl=$OPENSSL_MAIN \
        ./configure \
            --prefix=$BUILD_DIR/curl/build/osx/x64 \
            --with-secure-transport \
            --enable-static \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-shared \
            --disable-ldap \
            --disable-ldaps \
            --without-libidn2 \
            --enable-static \
            --disable-shared \
            --disable-verbose \
            --disable-threaded-resolver \
            --enable-ipv6 \
            --disable-ldap \
            --disable-ldaps \
            --host=x86_64-apple-darwin \
            --target=x86_64-apple-darwin
        make clean
        make -j${PARALLEL_MAKE}
        make install

        export ARCH=arm64

        export CFLAGS=" -arch $ARCH -m$SDK-version-min=$OSX_MIN_SDK_VER ${EXTRA_SYSROOT}"
        export LDFLAGS="-arch $ARCH -m$SDK-version-min=$OSX_MIN_SDK_VER ${EXTRA_SYSROOT}"

		./configure \
            --prefix=$BUILD_DIR/curl/build/osx/arm64 \
            --with-secure-transport \
            --enable-static \
            --without-nghttp2 \
            --without-libidn2 \
            --disable-shared \
            --disable-threaded-resolver \
            --enable-ipv6 \
            --disable-ldap \
            --disable-ldaps \
            --target=arm-apple-darwin \
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
        # ./buildconf
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
            export ARCH=$IOS_ARCH
            export SDK=iphoneos
            export DEPLOYMENT_TARGET=11.0
            ./configure \
                --with-secure-transport \
                --prefix=$BUILD_DIR/curl/build/$TYPE/${IOS_ARCH} \
                --enable-static \
                --disable-shared \
                --disable-ntlm-wb \
                --enable-ipv6 \
                --host=$HOST \
                --target=$HOST \
                --enable-threaded-resolver 
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
		./configure --with-openssl=$OPENSSL_DIR --enable-static --disable-shared
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
	cp -Rv build/$TYPE/include/curl/* $1/include/curl/

	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v "build/Win32/VC$VS_VER/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/Win32/libcurl.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v "build/Win64/VC$VS_VER/LIB Release - LIB OpenSSL/libcurl.lib" $1/lib/$TYPE/x64/libcurl.lib
		fi
	elif [ "$TYPE" == "osx" ] || [ "$TYPE" == "ios" ] || [ "$TYPE" == "tvos" ]; then
		# copy lib
		cp -Rv build/$TYPE/lib/libcurl.a $1/lib/$TYPE/curl.a
	elif [ "$TYPE" == "android" ] ; then
        #mkdir -p $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
		# copy lib
        cp -Rv build/curl/$ABI/libcurl.a $1/lib/$TYPE/$ABI/libcurl.a
	fi

  #   if [ "$TYPE" == "osx" ]; then
  #       cp build/$TYPE/x86/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
  #       cp build/$TYPE/x64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
  #   elif [ "$TYPE" == "ios" ]; then
  #       cp build/$TYPE/i386/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
  #       cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
  #   elif [ "$TYPE" == "tvos" ]; then
  #       cp build/$TYPE/x86_64/include/curl/curlbuild.h $1/include/curl/curlbuild64.h
  #   elif [ "$TYPE" == "vs" ]; then
		# if [ $ARCH == 32 ] ; then
  #           cp include/curl/curlbuild.h $1/include/curl/curlbuild32.h
  #       else
  #           cp include/curl/curlbuild.h $1/include/curl/curlbuild64.h
  #       fi
  #   elif [ "$TYPE" == "android" ]; then
		# cp build_$ABI/include/curl/curlbuild.h $1/include/curl/curlbuild32.h
  #   fi

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
