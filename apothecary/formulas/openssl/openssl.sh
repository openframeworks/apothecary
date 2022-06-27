#!/usr/bin/env bash
#
# openssl

# define the version
FORMULA_TYPES=( "osx" "vs" "ios" "tvos" "android" )

VER=1.1.0h
VERDIR=1.1.0
CSTANDARD=gnu11 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=https://www.openssl.org

# download the source code and unpack it into LIB_NAME
function download() {
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
	else
		if [ "$(shasum $FILENAME.tar.gz | awk '{print $1}')" == "$(cat $FILENAME.tar.gz.sha1)" ] ;  then
			tar -xf $FILENAME.tar.gz
			mv $FILENAME openssl
			rm $FILENAME.tar.gz
			rm $FILENAME.tar.gz.sha1
        else
			echoError "Invalid shasum for $FILENAME."
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
        sed -ie "s!LIBCRYPTO=-L.. -lcrypto!LIBCRYPTO=../libcrypto.a!g" Makefile
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
				./Configure darwin-i386-cc $FLAGS
			elif [ "${IOS_ARCH}" == "x86_64" ]; then
				./Configure darwin64-x86_64-cc $FLAGS
			elif [ "${IOS_ARCH}" == "armv7" ] && [ "${TYPE}" == "ios" ]; then
				./Configure ios-cross $FLAGS
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "tvos" ]; then
				./Configure tvos64-cross-arm64 $FLAGS
			elif [ "${IOS_ARCH}" == "arm64" ] && [ "${TYPE}" == "ios" ]; then
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
		perl -pi -e 's/install: all install_docs install_sw/install: install_docs install_sw/g' Makefile.org
		export _ANDROID_NDK_ROOT=$NDK_ROOT
		export FIPS_SIG=
		unset CXX
		unset CC
		unset AR
		rm -f Setenv-android.sh
		cp ../../formulas/openssl/Setenv-android.sh ./
		#wget -nv http://wiki.openssl.org/images/7/70/Setenv-android.sh
		perl -pi -e 's/^_ANDROID_EABI=(.*)$/#_ANDROID_EABI=\1/g' Setenv-android.sh
		perl -pi -e 's/^_ANDROID_ARCH=(.*)$/#_ANDROID_ARCH=\1/g' Setenv-android.sh
		perl -pi -e 's/^_ANDROID_API=(.*)$/#_ANDROID_API=\1/g' Setenv-android.sh
		perl -pi -e 's/\r//g' Setenv-android.sh
		export _ANDROID_API=$ANDROID_PLATFORM

        # armv7
        if [ "$ARCH" == "armv7" ]; then
            export _ANDROID_EABI=arm-linux-androideabi-4.9
		    export _ANDROID_ARCH=arch-arm
		elif [ "$ARCH" == "arm64" ]; then
			export _ANDROID_EABI=aarch64-linux-android-4.9
			export _ANDROID_ARCH=arch-arm64
		elif [ "$ARCH" == "x86" ]; then
            export _ANDROID_EABI=x86-4.9
		    export _ANDROID_ARCH=arch-x86
		fi

        local BUILD_TO_DIR=$BUILD_DIR/openssl/build/$TYPE/$ABI
        mkdir -p $BUILD_TO_DIR
        source Setenv-android.sh

		if [ "$ARCH" == "arm64" ]; then
			./Configure --openssldir=$BUILD_TO_DIR no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared android64-aarch64
		else
			./config --openssldir=$BUILD_TO_DIR no-ssl2 no-ssl3 no-comp no-hw no-engine no-shared
		fi
		make clean
        make depend -j${PARALLEL_MAKE}
        make build_libs -j${PARALLEL_MAKE}
        mkdir -p $BUILD_TO_DIR/lib
		cp libssl.a $BUILD_TO_DIR/lib/
        cp libcrypto.a $BUILD_TO_DIR/lib/

	else

		echoWarning "TODO: build $TYPE lib"

	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	#echoWarning "TODO: copy $TYPE lib"

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
	rm -rf $1/lib/$TYPE/* 2> /dev/null

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
		cp -rv build/android/$ABI/lib/*.a $1/lib/$TYPE/$ABI/
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
