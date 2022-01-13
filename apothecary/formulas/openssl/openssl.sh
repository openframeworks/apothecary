#!/usr/bin/env bash
#
# openssl

# define the version
FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" )

VER=1.1.1m
VERDIR=1.1.1
SHA1=39d424c4411e45f1570073d7a71b1830b96007ca

CSTANDARD=c17 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=https://www.openssl.org

# download the source code and unpack it into LIB_NAME
function download() {

	# if [ -f "$LIBS_DIR/openssl/$TYPE/$ABI/libssl.a" ]; then
	#     echo "Build Already exists at $LIBS_DIR/openssl/$TYPE/ skipping"
	# fi

	local FILENAME=openssl-$VER

	if ! [ -f $FILENAME ]; then
		wget -nv --no-check-certificate ${MIRROR}/source/$FILENAME.tar.gz
	fi

	if ! [ -f $FILENAME.sha1 ]; then
		wget -nv --no-check-certificate ${MIRROR}/source/$FILENAME.tar.gz.sha1
	fi
	if [ "$TYPE" == "vs" ] ; then
		#hasSha=$(cmd.exe /c 'call 'CertUtil' '-hashfile' '$FILENAME.tar.gz' 'SHA1'')
		echo "TO DO: check against the SHA for windows"
		tar -xf $FILENAME.tar.gz
		mv $FILENAME openssl
		rm $FILENAME.tar.gz
		rm $FILENAME.tar.gz.sha1

	# elif [ "$TYPE" == "android" ] ; then
	# 	wget -nv https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/ci-release-5843a396/openssl_1.1.1d-android-arm64.zip
	# 	tar -xf openssl_1.1.1d-android-arm64.zip
	# 	#wget -nv https://www.openssl.org/source/openssl-1.1.1i.tar.gz

	# 	#https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/ci-release-5843a396/openssl_1.1.1d-ios-arm64.zip
		
	# fi

	else
		CHECKSHA=$(shasum $FILENAME.tar.gz | awk '{print $1}')
		if [ $CHECKSHA != "$(cat $FILENAME.tar.gz.sha1)" || $CHECKSHA != "$SHA1" ] ;  then
			echoError "SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
        else
        	tar -xf $FILENAME.tar.gz
			echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
			mv $FILENAME openssl
			rm $FILENAME.tar.gz
			rm $FILENAME.tar.gz.sha1
			
		fi
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	if [ "$TYPE" == "tvos" ]; then
		cp $FORMULA_DIR/20-ios-tvos-cross.conf Configurations/
    elif [ "$TYPE" == "osx" ]; then
        cp $FORMULA_DIR/13-macos-arm.conf Configurations/  
    fi
}

# executed inside the lib src dir
function build() {

	


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
		if [ $ARCH == 32 ] ; then
			with_vs_env "c:\strawberry\perl\bin\perl Configure VC-WIN32 no-asm no-shared"
		elif [ $ARCH == 64 ] ; then
			with_vs_env "c:\strawberry\perl\bin\perl Configure VC-WIN64A no-asm no-shared"
		fi
		with_vs_env "nmake"

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
			IOS_ARCHS="x86_64 arm64 armv7" #armv7s
		fi

		unset LANG
		local LC_CTYPE=C
		local LC_ALL=C

		local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/
		rm -rf $BUILD_TO_DIR
  
		# loop through architectures! yay for loops!
		for IOS_ARCH in ${IOS_ARCHS}
		do
			# # make sure backed up
			# cp "Configure" "Configure.orig"
			# cp "apps/speed.c" "apps/speed.c.orig"
        
            ## Fix for tvOS fork undef 9.0
            if [ "${TYPE}" == "tvos" ]; then
                # Patch apps/speed.c to not use fork() since it's not available on tvOS
                sed -i -- 's/define HAVE_FORK 1/define HAVE_FORK 0/' "apps/speed.c"
            fi
            
            if [ "${IOS_ARCH}" == "x86_64" ]; then
                CUR_OS=$SIM_OS
            else
                CUR_OS=$IOS_OS
            fi
            
            local SDK_PATH=$(xcrun --sdk $CUR_OS --show-sdk-path)

			mkdir -p "$CURRENTPATH/build/$TYPE/$IOS_ARCH"
			source ../../ios_configure.sh $TYPE $IOS_ARCH
			# if  [ "$SDK" == "iphoneos" ] || [ "$SDK" == "appletvos" ]; then
			# 	cp "crypto/ui/ui_openssl.c" "crypto/ui/ui_openssl.c.orig"
			# 	sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
			# fi

			echo "Configuring ${IOS_ARCH}"
			FLAGS="no-async no-shared no-dso no-hw no-engine -w --openssldir=$CURRENTPATH/build/$TYPE/$IOS_ARCH --prefix=$CURRENTPATH/build/$TYPE/$IOS_ARCH -isysroot${SDK_PATH}"

			rm -f libcrypto.a
			rm -f libssl.a
			if [ "${IOS_ARCH}" == "i386" ]; then
				KERNEL_BITS=32
				./Configure darwin-i386-cc $FLAGS
			elif [ "${IOS_ARCH}" == "x86_64" ]; then
				KERNEL_BITS=64
				./Configure darwin64-x86_64-cc $FLAGS
			elif [ "${IOS_ARCH}" == "armv7" ] && [ "${TYPE}" == "ios" ]; then
				KERNEL_BITS=32
				./Configure ios-cross $FLAGS
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "tvos" ]; then
				KERNEL_BITS=64
				./Configure tvos64-cross-arm64 $FLAGS
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "ios" ]; then
				KERNEL_BITS=64
				./Configure ios64-cross $FLAGS
			fi
			make clean

			# For openssl 1.1.0
			# if [ "$TYPE" == "ios" ]; then
			#    CFLAG="-D_REENTRANT -arch ${IOS_ARCH}  -pipe -Os -gdwarf-2 $BITCODE -fPIC $MIN_TYPE$MIN_IOS_VERSION"
			#    CXXFLAG="-D_REENTRANT -arch ${IOS_ARCH}  -pipe -Os -gdwarf-2 $BITCODE -fPIC $MIN_TYPE$MIN_IOS_VERSION"
			# fi

			#sed -ie "s!^CFLAGS=\(.*\)!CFLAGS=$CFLAGS \1!" Makefile
			sed -ie "s!^CFLAG=\(.*\)!CFLAG=\1 $CFLAGS !" Makefile
			sed -ie "s!LIBCRYPTO=-L.. -lcrypto!LIBCRYPTO=../libcrypto.a!g" Makefile
			sed -ie "s!LIBSSL=-L.. -lssl!LIBSSL=../libssl.a!g" Makefile

			echo "Running make for ${IOS_ARCH}"
			make clean
			make -j1 depend # running make multithreaded is unreliable
			make -j1
			make -j1 install_sw


			# reset source file back.
			# if  [ "$SDK" == "iphoneos" ] || [ "$SDK" == "appletvos" ]; then
			# 	cp "crypto/ui/ui_openssl.c.orig" "crypto/ui/ui_openssl.c"
			# fi
			# cp "apps/speed.c.orig" "apps/speed.c"

		done

		unset CC CFLAG CFLAGS
		unset PLATFORM CROSS_TOP CROSS_SDK BUILD_TOOLS
		unset IOS_DEVROOT IOS_SDKROOT


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
		FLAGS="no-asm  no-async shared no-dso no-comp no-deprecated no-md2 no-rc5 no-rfc3779 no-unit-test no-sctp no-ssl-trace no-ssl2 no-ssl3 no-engine no-weak-ssl-ciphers -w -stdlib=libc++ -ldl -lc -L$DEEP_TOOLCHAIN_PATH -L$TOOLCHAIN/lib/gcc/$ANDROID_POSTFIX/4.9.x/"
		./Configure $CONFIGURE  -D__ANDROID_API__=$ANDROID_API $FLAGS --prefix="$CURRENTPATH/$BUILD_TO_DIR" --openssldir="$CURRENTPATH/$BUILD_TO_DIR"
 
 
		#perl configdata.pm --dump
		#make
		 
		make clean
		make AR=$AR depend 
		echo "Make Depend Complete"
		make all


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

		echoWarning "TODO: build $TYPE lib"

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	#echoWarning "TODO: copy $TYPE lib"

	if [ -f "$LIBS_DIR/openssl/$TYPE/$ABI/libssl.a" ]; then
	    echo "Build Already exists at $LIBS_DIR/openssl/$TYPE/ skipping"
	fi

	# # headers
	# if [ -d $1/include/ ]; then
	# 	# keep a copy of the platform specific headers
	# 	find $1/include/openssl/ -name \opensslconf_*.h -exec cp {} $FORMULA_DIR/ \;
	# 	# remove old headers
	# 	rm -r $1/include/
	# 	# restore platform specific headers
	# 	find $FORMULA_DIR/ -name \opensslconf_*.h -exec cp {} $1/include/openssl/ \;
	# fi

	mkdir -pv $1/include/openssl/
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ]; then
		PREFIX=`pwd`/build/
		if [ $ARCH == 32 ] ; then
			PLATFORM="Win32"
		else
			PLATFORM="x64"
		fi
	fi

	# opensslconf.h is different in every platform, we need to copy
	# it as opensslconf_$(TYPE).h and use a modified version of
	# opensslconf.h that detects the platform and includes the
	# correct one. Then every platform checkouts the rest of the config
	# files that were deleted here
	if [[ "$TYPE" == "osx" || "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
		if [ -f build/$TYPE/include/openssl/opensslconf.h ]; then
			mv build/$TYPE/include/openssl/opensslconf.h build/$TYPE/include/openssl/opensslconf_${TYPE}.h
		fi
		cp -RHv build/$TYPE/include/openssl/* $1/include/openssl/
		cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h

	elif [ "$TYPE" == "vs" ]; then
		mv include/openssl/opensslconf.h include/openssl/opensslconf_${TYPE}.h
		cp -RHv include/openssl/* $1/include/openssl/
		cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h

	elif [ -f include/openssl/opensslconf.h ]; then
		mv include/openssl/opensslconf.h include/openssl/opensslconf_${TYPE}.h
		cp -RHv include/openssl/* $1/include/openssl/
		cp -v $FORMULA_DIR/opensslconf.h $1/include/openssl/opensslconf.h
	fi
	# suppress file not found errors
	# same here doesn't seem to be a solid reason to delete the files
	#rm -rf $1/lib/$TYPE/* 2> /dev/null

	# libs
	if [[ "$TYPE" == "ios" || "${TYPE}" == "tvos" ]] || [ "$TYPE" == "osx" ] ; then
		cp -v build/$TYPE/lib/libcrypto.a $1/lib/$TYPE/crypto.a
		cp -v build/$TYPE/lib/libssl.a $1/lib/$TYPE/ssl.a
	elif [ "$TYPE" == "vs" ] ; then
		rm -rf $1/lib/$TYPE/${PLATFORM}
		mkdir -p $1/lib/$TYPE/${PLATFORM}
		cp -v *.lib $1/lib/$TYPE/${PLATFORM}/
		mv include/openssl/opensslconf_vs.h include/openssl/opensslconf.h
		# for f in $1/lib/$TYPE/${PLATFORM}/*; do
		# 	base=`basename $f .lib`
		# 	mv -v $f $1/lib/$TYPE/${PLATFORM}/${base}md.lib
		# done
	elif [ "$TYPE" == "android" ] ; then
		if [ -d $1/lib/$TYPE/$ABI ]; then
			rm -r $1/lib/$TYPE/$ABI
		fi
		mkdir -p $1/lib/$TYPE/$ABI
		cp -rv *.a $1/lib/$TYPE/$ABI/
		# cp -rv build_$ABI/crypto/*.a $1/lib/$TYPE/$ABI/
		mv include/openssl/opensslconf_android.h include/openssl/opensslconf.h

		# 	mkdir -p $1/lib/$TYPE/armeabi-v7a
		# 	cp -v lib/Android/armeabi-v7a/*.a $1/lib/$TYPE/armeabi-v7a

		# 	mkdir -p $1/lib/$TYPE/x86
		# 	cp -v lib/Android/x86/*.a $1/lib/$TYPE/x86
	else
		echoWarning "TODO: copy $TYPE lib"
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE $1/license/


}

# executed inside the lib src dir
function clean() {
	echoWarning "TODO: clean $TYPE lib"
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
		# elif [ "$TYPE" == "android" ] ; then
		# 	export PATH=$PATH:$ANDROID_TOOLCHAIN_ANDROIDEABI/bin:$ANDROID_TOOLCHAIN_X86/bin
		# 	make clean ANDROID_ABI=armeabi
		# 	make clean ANDROID_ABI=armeabi-v7a
		# 	make clean ANDROID_ABI=x86
		# 	unset PATH
	elif [[ "$TYPE" == "osx" ]] ; then
		make clean
		# clean up old build folder
		rm -rf /build
		# clean up compiled libraries
		rm -rf /lib
		rm -rf *.a
	else
		make clean
	fi
}
