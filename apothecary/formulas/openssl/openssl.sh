#!/usr/bin/env bash
#
# openssl

# define the version
FORMULA_TYPES=( "osx"  "ios" "tvos" "vs" ) 

VER=1.1.1w
VERDIR=1.1.1
SHA1=76fbf3ca4370e12894a408ef75718f32cdab9671
SHA256=cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8

CSTANDARD=c17 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=https://www.openssl.org

# download the source code and unpack it into LIB_NAME
function download() {

	. "$DOWNLOADER_SCRIPT"
	local FILENAME=openssl-$VER

	if ! [ -f $FILENAME ]; then
		downloader ${MIRROR}/source/$FILENAME.tar.gz
	fi

	if ! [ -f $FILENAME.sha1 ]; then
		# https://www.openssl.org/source/openssl-1.1.1n.tar.gz.sha1
		downloader ${MIRROR}/source/$FILENAME.tar.gz.sha1
	fi
	CHECKSHA=$(shasum $FILENAME.tar.gz | awk '{print $1}')
	FILESUM=$(head -1 $FILENAME.tar.gz.sha1)
	if [[ " $CHECKSHA" != $FILESUM || $CHECKSHA != "$SHA1" ]] ;  then
		echoError "SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] FILESUM=[$FILESUM]- Developer has not updated SHA or Man in the Middle Attack"
    	exit
    else
    	tar -xf $FILENAME.tar.gz
		echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
		mv $FILENAME openssl
		rm $FILENAME.tar.gz
		rm $FILENAME.tar.gz.sha1
		
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "tvos" ]; then
		cp $FORMULA_DIR/20-ios-tvos-cross.conf Configurations/
    elif [ "$TYPE" == "osx" ]; then
        cp $FORMULA_DIR/13-macos-arm.conf Configurations/  
    elif [ "$TYPE" == "vs" ]; then        
    	cp -f $FORMULA_DIR/openssl-cmake/CMakeLists.txt .
    	cp -f $FORMULA_DIR/openssl-cmake/*.cmake .
		cp -f $FORMULA_DIR/openssl-cmake/crypto/* ./crypto/
		mkdir -p ./cmake/
		cp -f $FORMULA_DIR/openssl-cmake/apps/* ./apps/
		cp -f $FORMULA_DIR/openssl-cmake/cmake/* ./cmake/
		cp -f $FORMULA_DIR/openssl-cmake/ssl/CMakeLists.txt ./ssl/CMakeLists.txt
    fi




}

# executed inside the lib src dir
function build() {

	BUILD_OPTS="-DOPENSSL_NO_DEPRECATED -DOPENSSL_NO_COMP -DOPENSSL_NO_EC_NISTP_64_GCC_128 -DOPENSSL_NO_ENGINE -DOPENSSL_NO_GMP -DOPENSSL_NO_JPAKE -DOPENSSL_NO_LIBUNBOUND -DOPENSSL_NO_MD2 -DOPENSSL_NO_RC5 -DOPENSSL_NO_RFC3779 -DOPENSSL_NO_SCTP -DOPENSSL_NO_SSL_TRACE -DOPENSSL_NO_SSL2 -DOPENSSL_NO_SSL3 -DOPENSSL_NO_STORE -DOPENSSL_NO_UNIT_TEST -DOPENSSL_NO_WEAK_SSL_CIPHERS"
	
	BUILD_OPTS_CMAKE=" -DOPENSSL_NO_DEPRECATED=ON \
	-DOPENSSL_NO_COMP=ON \
	-DOPENSSL_NO_EC_NISTP_64_GCC_128=ON \
	-DOPENSSL_NO_ENGINE=ON \
	-DOPENSSL_NO_GMP=ON \
	-DOPENSSL_NO_JPAKE=ON \
	-DOPENSSL_NO_LIBUNBOUND=ON \
	-DOPENSSL_NO_MD2=ON \
	-DOPENSSL_NO_RC5=ON \
	-DOPENSSL_NO_RFC3779=ON \
	-DOPENSSL_NO_SCTP=ON \
	-DOPENSSL_NO_SSL_TRACE=ON \
	-DOPENSSL_NO_SSL2=ON \
	-DOPENSSL_NO_SSL3=ON \
	-DOPENSSL_NO_STORE=ON \
	-DOPENSSL_NO_UNIT_TEST=ON \
	-DOPENSSL_NO_WEAK_SSL_CIPHERS=ON \
	-DOPENSSL_NO_ASAN=ON \
	-DOPENSSL_NO_ASM=ON \
	-DOPENSSL_NO_CRYPTO_MDEBUG=ON \
	-DOPENSSL_NO_CRYPTO_MDEBUG_BACKTRACE=ON \
	-DOPENSSL_NO_DEVCRYPTOENG=ON \
	-DOPENSSL_NO_EGD=ON \
	-DOPENSSL_NO_EXTERNAL_TESTS=ON \
	-DOPENSSL_NO_FUZZ_AFL=ON \
	-DOPENSSL_NO_FUZZ_LIBFUZZER=ON \
	-DOPENSSL_NO_HEARTBEATS=ON \
	-DOPENSSL_NO_MSAN=ON \
	-DOPENSSL_NO_UBSAN=ON \
	-DOPENSSL_NO_UNIT_TEST=ON \
	-DOPENSSL_NO_WEAK_SSL_CIPHERS=ON \
	-DOPENSSL_NO_STATIC_ENGINE=ON \
	-DOPENSSL_NO_AFALGENG=ON"

	if [ "$TYPE" == "osx" ] ; then
  
		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
		rm -rf $BUILD_TO_DIR
		rm -f libcrypto.a libssl.a
  
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

		local BUILD_OPTS_ARM="-fPIC -isysroot${SDK_PATH} -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} no-shared no-asm darwin64-arm64-cc"
		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/arm64
        KERNEL_BITS=64
                
		rm -f libcrypto.a
		rm -f libssl.a
		./Configure $BUILD_OPTS_ARM --openssldir=$BUILD_TO_DIR --prefix=$BUILD_TO_DIR
		sed -ie "s!LIBCRYPTO=-L.. -lcrypto!LIBCRYPTO=../libcrypto.a!g" Makefile
		sed -ie "s!LIBSSL=-L.. -lssl!LIBSSL=../libssl.a!g" Makefile
		make clean
		make -j1 depend # running make multithreaded is unreliable
		make -j1
		make -j1 install_sw
  
        local BUILD_OPTS_X86_64="-fPIC -isysroot${SDK_PATH} -stdlib=libc++ -mmacosx-version-min=${OSX_MIN_SDK_VER} no-shared darwin64-x86_64-cc"

        rm -f libcrypto.a
        rm -f libssl.a
        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/x64
        
        ./Configure $BUILD_OPTS_X86_64 --openssldir=$BUILD_TO_DIR --prefix=$BUILD_TO_DIR
        sed -ie "s!LIBSSL=-L.. -lssl!LIBSSL=../libssl.a!g" Makefile
        make clean
        make -j1 depend
        make -j1
        make -j1 install_sw

		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
		cp -r $BUILD_TO_DIR/x64/* $BUILD_TO_DIR/

		lipo -create $BUILD_TO_DIR/arm64/lib/libcrypto.a \
		$BUILD_TO_DIR/x64/lib/libcrypto.a \
		-output $BUILD_TO_DIR/lib/libcrypto.a

		lipo -create $BUILD_TO_DIR/arm64/lib/libssl.a \
		$BUILD_TO_DIR/x64/lib/libssl.a \
		-output $BUILD_TO_DIR/lib/libssl.a

	elif [ "$TYPE" == "vs" ] ; then

		echo "building openssl $TYPE | $ARCH | $VS_VER | vs: $VS_VER_GEN"
        echo "--------------------"
        GENERATOR_NAME="Visual Studio ${VS_VER_GEN}"
        pwd 
        if [ -d "build_${TYPE}_${ARCH}" ]; then
		    rm -rf "build_${TYPE}_${ARCH}"
		fi
        mkdir -p "build_${TYPE}_${ARCH}"
        cd "build_${TYPE}_${ARCH}"
        pwd

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
            -DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_C_FLAGS="-DUSE_PTHREADS=1" \
            -DCMAKE_CXX_EXTENSIONS=OFF \
            -DBUILD_SHARED_LIBS=OFF \
            -DCMAKE_BUILD_TYPE=Release \
            -DOPENSSL_INSTALL_MAN=ON \
            -DCMAKE_INSTALL_LIBDIR="lib" \
            ${BUILD_OPTS_CMAKE} \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"

        cmake --build . --config Release --target install

        cd ..

	elif [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then

		# This was quite helpful as a reference: https://github.com/x2on/OpenSSL-for-iPhone
		# Refer to the other script if anything drastic changes for future versions

		CURRENTPATH=`pwd`

		local IOS_ARCHS
        local IOS_OS="iphoneos"
        local SIM_OS="macosx"

		if [ "${TYPE}" == "tvos" ]; then
			IOS_ARCHS="x86_64 arm64"
            IOS_OS="appletvos"
		elif [ "$TYPE" == "ios" ]; then
			IOS_ARCHS="arm64 x86_64 armv7" #armv7s
		fi

		unset LANG
		local LC_CTYPE=C
		local LC_ALL=C

		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
		rm -rf $BUILD_TO_DIR
  
		# # make sure backed up if multiplatform compiling apothecary 
  		cp "apps/speed.c" "apps/speed.c.orig"
		cp "test/drbgtest.c" "test/drbgtest.c.orig"
		cp "apps/ocsp.c" "apps/ocsp.c.orig"
		cp "crypto/async/arch/async_posix.c" "crypto/async/arch/async_posix.c.orig"
		cp "crypto/ui/ui_openssl.c" "crypto/ui/ui_openssl.c.orig"
		

		# loop through architectures! yay for loops!
		for IOS_ARCH in ${IOS_ARCHS}
		do

			mkdir -p "$CURRENTPATH/build/$TYPE/$IOS_ARCH"
			source ../../ios_configure.sh $TYPE $IOS_ARCH

            ## Fix for tvOS fork undef 9.0
            if [ "${TYPE}" == "tvos" ]; then

                # Patch apps/speed.c to not use fork()
                sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "apps/speed.c"
                sed -i -- 's/fork()/-1/' "./test/drbgtest.c"
				sed -i -- 's/!defined(OPENSSL_NO_POSIX_IO)/defined(HAVE_FORK)/' "./apps/ocsp.c"
				sed -i -- 's/fork()/-1/' "./apps/ocsp.c"
				sed -i -- 's/!defined(OPENSSL_NO_ASYNC)/defined(HAVE_FORK)/' "./crypto/async/arch/async_posix.h"
				# Patch Configure to build for tvOS, not iOS
				sed -i -- 's/D\_REENTRANT\:iOS/D\_REENTRANT\:tvOS/' "./Configure"

				
                echo "tvos patched files for fork() issue and tvOS changes"
                EXTRA_FLAGS="-DNO_FORK"
            else
            	EXTRA_FLAGS=""
            fi

            sed -ie "s!CNF_CFLAGS=\(.*\)!CNF_CFLAGS=$CFLAGS !" "./Configure" 
            
            if [ "${IOS_ARCH}" == "x86_64" ]; then
                CUR_OS=$SIM_OS
            else
                CUR_OS=$IOS_OS
            fi
            
            local SDK_PATH=$(xcrun --sdk $CUR_OS --show-sdk-path)

			
		

			BUILD_OPTS="-DOPENSSL_NO_DEPRECATED -DOPENSSL_NO_COMP -DOPENSSL_NO_EC_NISTP_64_GCC_128 -DOPENSSL_NO_ENGINE -DOPENSSL_NO_GMP -DOPENSSL_NO_JPAKE -DOPENSSL_NO_LIBUNBOUND -DOPENSSL_NO_MD2 -DOPENSSL_NO_RC5 -DOPENSSL_NO_RFC3779 -DOPENSSL_NO_SCTP -DOPENSSL_NO_SSL_TRACE -DOPENSSL_NO_SSL2 -DOPENSSL_NO_SSL3 -DOPENSSL_NO_STORE -DOPENSSL_NO_UNIT_TEST -DOPENSSL_NO_WEAK_SSL_CIPHERS"
		

			echo "Configuring ${IOS_ARCH}"
			FLAGS="no-asm no-async no-shared no-dso no-hw no-engine -w --openssldir=$CURRENTPATH/build/$TYPE/$IOS_ARCH --prefix=$CURRENTPATH/build/$TYPE/$IOS_ARCH -isysroot${SDK_PATH} "

			rm -f libcrypto.a
			rm -f libssl.a

			chmod u+x ./Configure

			if [ "${IOS_ARCH}" == "i386" ]; then
				KERNEL_BITS=32
				./Configure darwin-i386-cc $FLAGS 
				echo "Configure darwin-i386-cc $FLAGS"
			elif [ "${IOS_ARCH}" == "x86_64" ] && [ "${TYPE}" == "ios" ]; then
				KERNEL_BITS=64
				./Configure darwin64-x86_64-cc $FLAGS 
				echo "Configure darwin-x86_64-cc $FLAGS"
			elif [ "${IOS_ARCH}" == "x86_64" ] && [ "${TYPE}" == "tvos" ]; then
				KERNEL_BITS=64
				./Configure iphoneos-cross $FLAGS 
				echo "Configure tvos-sim-cross-x86_64 $FLAGS"
			elif [ "${IOS_ARCH}" == "armv7" ] && [ "${TYPE}" == "ios" ]; then
				KERNEL_BITS=32
				./Configure iphoneos-cross $FLAGS
				echo "Configure  ios-cross $FLAGS"
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "tvos" ]; then
				KERNEL_BITS=64
				./Configure iphoneos-cross $FLAGS 
				echo "Configure  ios64-cross for tvOS arm64 $FLAGS"
				# sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "ios" ]; then
				KERNEL_BITS=64
				./Configure ios64-cross $FLAGS
				echo "Configure  ios64-cross for iOS arm64 $FLAGS"
			else 
				KERNEL_BITS=64
				./Configure ios64-cross $FLAGS
				echo "Configure  ios64-cross for other $FLAGS"
			fi

			find . -type f -name '*.o' -exec rm {} +
			
			make clean

			sed -ie "s!^CFLAG=\(.*\)!CFLAG=\1 $CFLAGS !" Makefile
			sed -ie "s!LIBCRYPTO=-L.. -lcrypto!LIBCRYPTO=../libcrypto.a!g" Makefile
			sed -ie "s!LIBSSL=-L.. -lssl!LIBSSL=../libssl.a!g" Makefile

			echo "Running make for ${IOS_ARCH}"
			make clean
			make -j1 depend # running make multithreaded is unreliable
			make -j1
			make -j1 install_sw

			export CC=""
			export CXX=""
			export CFLAGS=""
			export LDFLAGS=""
			export CPPFLAGS=""

		done

		unset CC CFLAG CFLAGS
		unset PLATFORM CROSS_TOP CROSS_SDK BUILD_TOOLS
		unset IOS_DEVROOT IOS_SDKROOT

		cp "apps/speed.c.orig" "apps/speed.c"
		cp "test/drbgtest.c.orig" "test/drbgtest.c"
		cp "apps/ocsp.c.orig" "apps/ocsp.c"
		cp "crypto/async/arch/async_posix.c.orig" "crypto/async/arch/async_posix.c"
		cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"


		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
		cp -r $BUILD_TO_DIR/x86_64/* $BUILD_TO_DIR/

		if [ "${TYPE}" == "tvos" ]; then
			lipo -create $BUILD_TO_DIR/arm64/lib/libcrypto.a \
			$BUILD_TO_DIR/x86_64/lib/libcrypto.a \
			-output $BUILD_TO_DIR/lib/libcrypto.a

			lipo -create $BUILD_TO_DIR/arm64/lib/libssl.a \
			$BUILD_TO_DIR/x86_64/lib/libssl.a \
			-output $BUILD_TO_DIR/lib/libssl.a
		elif [ "$TYPE" == "ios" ]; then
			lipo -create $BUILD_TO_DIR/armv7/lib/libcrypto.a \
			$BUILD_TO_DIR/arm64/lib/libcrypto.a \
			$BUILD_TO_DIR/x86_64/lib/libcrypto.a \
			-output $BUILD_TO_DIR/lib/libcrypto.a

			lipo -create $BUILD_TO_DIR/armv7/lib/libssl.a \
			$BUILD_TO_DIR/arm64/lib/libssl.a \
			$BUILD_TO_DIR/x86_64/lib/libssl.a \
			-output $BUILD_TO_DIR/lib/libssl.a
		fi

		# cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"

	elif [ "$TYPE" == "android" ]; then

		if [ -f "$LIBS_DIR/openssl/$TYPE/$ABI/libssl.a" ]; then
	    	echo "Build Already exists at $LIBS_DIR/openssl/$TYPE/ skipping"
	    	return
		fi


		 source ../../android_configure.sh $ABI make

		 #wget -nv https://wiki.openssl.org/images/7/70/Setenv-android.sh
		 # source ./setenv-android.sh
		echo "NDK_ROOT: $NDK_ROOT"

		export RELEASE=2.6.37
		export SYSTEM=android
		export ARCH=arm
		export CROSS_COMPILE="arm-linux-androideabi-"



		export ANDROID_SYSROOT="$SYSROOT"
		#export SYSROOT="$ANDROID_SYSROOT"
		export NDK_SYSROOT="$ANDROID_SYSROOT"
		export ANDROID_NDK_SYSROOT="$ANDROID_SYSROOT"
		#export ANDROID_API="$ANDROID_API"

		# CROSS_COMPILE and ANDROID_DEV are DFW (Don't Fiddle With). Its used by OpenSSL build system.
		# export CROSS_COMPILE="arm-linux-androideabi-"
		export ANDROID_DEV="$ANDROID_NDK_ROOT/platforms/$ANDROID_API/$ABI/usr"
		export HOSTCC=clang

		export ANDROID_TOOLCHAIN="$TOOLCHAIN"

		# Fix NDK 23 Issue with sysroot for old make
		cp $DEEP_TOOLCHAIN_PATH/crtbegin_dynamic.o $SYSROOT/usr/lib/crtbegin_dynamic.o
		cp $DEEP_TOOLCHAIN_PATH/crtbegin_so.o $SYSROOT/usr/lib/crtbegin_so.o
		cp $DEEP_TOOLCHAIN_PATH/crtend_android.o $SYSROOT/usr/lib/crtend_android.o
		cp $DEEP_TOOLCHAIN_PATH/crtend_so.o $SYSROOT/usr/lib/crtend_so.o
		

		VERBOSE=1
		if [ ! -z "$VERBOSE" ] && [ "$VERBOSE" != "0" ]; then
		  echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
		  echo "ANDROID_ARCH: $ABI"
		  # echo "ANDROID_EABI: $_ANDROID_EABI"
		  echo "ANDROID_API: $ANDROID_API"
		  echo "ANDROID_SYSROOT: $ANDROID_SYSROOT"
		  echo "ANDROID_TOOLCHAIN: $ANDROID_TOOLCHAIN"
		  #echo "FIPS_SIG: $FIPS_SIG"
		  #echo "CROSS_COMPILE: $CROSS_COMPILE"
		  echo "ANDROID_DEV: $ANDROID_DEV"
		fi

		#cp $FORMULA_DIR/Setenv-android.sh ./Setenv-android.sh
		#chmod 755 ./Setenv-android.sh
		#./setenv-android.sh

		perl -pi -e 's/install: all install_docs install_sw/install: install_docs install_sw/g' Makefile.org




		export BUILD_TO_DIR=build_$ABI
		CURRENTPATH=`pwd`
		mkdir -p BUILD_TO_DIR
		echo "Build Dir $BUILD_TO_DIR"
		export PATH="$TOOLCHAIN_PATH:$DEEP_TOOLCHAIN_PATH:$PATH"
		# echo "./Config:"
		# ./config --prefix=$CURRENTPATH/$BUILD_TO_DIR --openssldir=$CURRENTPATH/$BUILD_TO_DIR no-ssl2 no-ssl3 no-comp no-hw no-engine shared
		#./Configure android-arm64
		

		# cp $FORMULA_DIR/openssl-cmake/CMakeLists.txt $CURRENTPATH/
		# cp $FORMULA_DIR/openssl-cmake/crypto/* $CURRENTPATH/crypto/
		# mkdir -p $CURRENTPATH/cmake/
		# cp $FORMULA_DIR/openssl-cmake/cmake/* $CURRENTPATH/cmake/
		# cp $FORMULA_DIR/openssl-cmake/ssl/CMakeLists.txt $CURRENTPATH/ssl/

		echo `pwd`
		# cp crypto/comp/comp.h include/openssl/
		# cp crypto/engine/engine.h include/

		BUILD_OPTS="-DOPENSSL_NO_DEPRECATED -DOPENSSL_NO_COMP -DOPENSSL_NO_EC_NISTP_64_GCC_128 -DOPENSSL_NO_ENGINE -DOPENSSL_NO_GMP -DOPENSSL_NO_JPAKE -DOPENSSL_NO_LIBUNBOUND -DOPENSSL_NO_MD2 -DOPENSSL_NO_RC5 -DOPENSSL_NO_RFC3779 -DOPENSSL_NO_SCTP -DOPENSSL_NO_SSL_TRACE -DOPENSSL_NO_SSL2 -DOPENSSL_NO_SSL3 -DOPENSSL_NO_STORE -DOPENSSL_NO_UNIT_TEST -DOPENSSL_NO_WEAK_SSL_CIPHERS"
		
		if [ "$ABI" = "armeabi-v7a" ]; then
			KERNEL_BITS=32
		    export CONFIGURE="android-arm"
		    #PATH=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/$HOST_PLATFORM/bin:$PATH
		elif [ "$ABI" = "armeabi" ]; then
			KERNEL_BITS=32
		    export CONFIGURE="android-arm"
		    #PATH=$ANDROID_NDK_ROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin:$PATH
		elif [ $ABI = "arm64-v8a" ]; then
			KERNEL_BITS=64
		    export CONFIGURE="android-arm64"
		    #PATH=$ANDROID_NDK_ROOT/toolchains/aarch64-linux-android-4.9/prebuilt/aarch64-$HOST_PLATFORM/bin:$PATH
		elif [ "$ABI" = "x86_64" ]; then
			KERNEL_BITS=32
		    export CONFIGURE="android-x86_64"
		elif [ "$ABI" = "x86" ]; then
			KERNEL_BITS=32
		    export CONFIGURE="android-x86"
		fi
		
		
		

		echo "PATH:$PATH"
		#export PATH=-I${SYSROOT}/usr/lib/
		export OUTPUT_DIR=
		echo "./Configure: $DEEP_TOOLCHAIN_PATH/usr/lib/"
		FLAGS="no-asm  no-async shared no-dso no-comp no-deprecated no-md2 no-rc5 no-rfc3779 no-unit-test no-sctp no-ssl-trace no-ssl2 no-ssl3 no-engine no-weak-ssl-ciphers -w -std=c17 -ldl -shared -lc -L$DEEP_TOOLCHAIN_PATH -L$TOOLCHAIN/lib/gcc/$ANDROID_POSTFIX/4.9.x/"
		./Configure $CONFIGURE  -D__ANDROID_API__=$ANDROID_API $FLAGS --prefix="$CURRENTPATH/$BUILD_TO_DIR" --openssldir="$CURRENTPATH/$BUILD_TO_DIR"
 
 
		#perl configdata.pm --dump
		#make
		 
		make clean
		make AR=$AR depend 
		echo "Make Depend Complete"
		make all

		mkdir -p build/$TYPE/$ABI
		cp -rv *.a build/$TYPE/$ABI

		rm $SYSROOT/usr/lib/crtbegin_dynamic.o
		rm $SYSROOT/usr/lib/crtbegin_so.o
		rm $SYSROOT/usr/lib/crtend_android.o
		rm $SYSROOT/usr/lib/crtend_so.o

		#ake all
		
		
		# cmake -G 'Unix Makefiles' -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" -DANDROID_ABI=$ABI -DCMAKE_C_FLAGS="-I$CURRENTPATH/include $BUILD_OPTS"  ..
		# make VERBOSE=1
		# mkdir -p inst
		# make DESTDIR="inst" install 

	else

		# cd build-linux-x86_64
  #       - cmake ../ -DBUILD_OPENSSL=ON -DOPENSSL_BUILD_VERSION=$OPENSSL_BUILD_VERSION -DOPENSSL_BUILD_HASH=$OPENSSL_BUILD_HASH -DOPENSSL_INSTALL_MAN=ON -DOPENSSL_ENABLE_TESTS=ON
  #       - chmod -R 777 .  

		echoWarning "TODO: build $TYPE lib"

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	
	if [[ "$TYPE" == "osx" || "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
		if [ -f build/$TYPE/include/openssl/opensslconf.h ]; then
			mv build/$TYPE/include/openssl/opensslconf.h build/$TYPE/include/openssl/opensslconf_${TYPE}.h
		fi
		cp -RHv build/$TYPE/include/openssl/* $1/include/openssl/
		cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h

	elif [ "$TYPE" == "vs" ]; then
		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE
        mkdir -p $1/lib/$TYPE/$PLATFORM/

        FILE_POSTFIX=-x64
        if [ ${ARCH} == "32" ]; then
        	FILE_POSTFIX=""
        fi
        cp -Rv "build_${TYPE}_${ARCH}/Release/include/" $1/ 
        cp -f "build_${TYPE}_${ARCH}/Release/lib/libcrypto-1_1${FILE_POSTFIX}.lib" $1/lib/$TYPE/$PLATFORM/libcrypto.lib 
        cp -f "build_${TYPE}_${ARCH}/Release/lib/libssl-1_1${FILE_POSTFIX}.lib" $1/lib/$TYPE/$PLATFORM/libssl.lib 
	fi  

	if [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] || [ "$TYPE" == "osx" ] ; then
		cp -v build/$TYPE/lib/libcrypto.a $1/lib/$TYPE/crypto.a
		cp -v build/$TYPE/lib/libssl.a $1/lib/$TYPE/ssl.a
	elif [ "$TYPE" == "android" ] ; then
		if [ -d $1/lib/$TYPE/$ABI ]; then
			rm -r $1/lib/$TYPE/$ABI
		fi
		mkdir -p $1/lib/$TYPE/$ABI
		cp -rv build/$TYPE/$ABI/*.a $1/lib/$TYPE/$ABI/
		# cp -rv build_$ABI/crypto/*.a $1/lib/$TYPE/$ABI/
		mv include/openssl/opensslconf_android.h include/openssl/opensslconf.h
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
	
	if [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] ; then
		make clean
		# clean up old build folder
		rm -rf /build
		# clean up compiled libraries
		rm -rf /lib
		# reset files back to original if
		cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"
		cp "Makefile.orig" "Makefile"
		cp "Configure.orig" "Configure"
		# if [ "$TYPE" == "vs" ] ; then
		# 	cmd //c buildwin.cmd ${VS_VER}0 clean static_md both Win32 nosamples notests
	elif [ "$TYPE" == "vs" ] ; then
		if [ -d "build_${TYPE}_${ARCH}" ]; then
		    # Delete the folder and its contents
		    rm -r build_${TYPE}_${ARCH}	    
		fi
	elif [[ "$TYPE" == "osx" ]] ; then
		make clean
		# clean up old build folder
		rm -rf /build
		# clean up compiled libraries
		rm -rf /lib
		rm -rf *.a
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
    if loadsave ${TYPE} "openssl" ${ARCH} ${VER} "${SAVE_FILE}"; then
      return 0;
    else
      return 1;
    fi
}
