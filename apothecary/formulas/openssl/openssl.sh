#!/usr/bin/env bash
#
# openssl

# define the version
FORMULA_TYPES=(  )

FORMULA_DEPENDS=( )

VER=3.2.1
VERDIR=3.2.1
SHA1=9668723d65d21a9d13e985203ce8c27ac5ecf3ae
SHA256=83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39

CSTANDARD=c17 # c89 | c99 | c11 | gnu11
SITE=https://www.openssl.org
MIRROR=https://www.openssl.org

GIT_URL=$SITE

# download the source code and unpack it into LIB_NAME
function download() {

	. "$DOWNLOADER_SCRIPT"
	local FILENAME=openssl-$VER

	if ! [ -f $FILENAME ]; then
		downloader ${MIRROR}/source/$FILENAME.tar.gz
	fi

	if ! [ -f $FILENAME.sha1 ]; then
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
    cp -f $FORMULA_DIR/openssl-cmake/CMakeLists.txt .
	cp -f $FORMULA_DIR/openssl-cmake/*.cmake .
	cp -f $FORMULA_DIR/openssl-cmake/crypto/* ./crypto/
	mkdir -p ./cmake/
	cp -f $FORMULA_DIR/openssl-cmake/apps/* ./apps/
	cp -f $FORMULA_DIR/openssl-cmake/cmake/* ./cmake/
	cp -f $FORMULA_DIR/openssl-cmake/ssl/CMakeLists.txt ./ssl/CMakeLists.txt



}

# executed inside the lib src dir
function build() {

	LIBS_ROOT=$(realpath $LIBS_DIR)
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

	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
		echo "building $TYPE | $PLATFORM"
        echo "--------------------"
		mkdir -p "build_${TYPE}_${PLATFORM}"
		cd "build_${TYPE}_${PLATFORM}"
		rm -f CMakeCache.txt *.a *.o
		cmake  .. \
			-DCMAKE_C_STANDARD=17 \
			-DCMAKE_CXX_STANDARD=17 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE}" \
			-DCMAKE_C_FLAGS="-DUSE_PTHREADS=1 ${FLAG_RELEASE} " \
			-DCMAKE_CXX_EXTENSIONS=OFF \
			-DBUILD_SHARED_LIBS=OFF \
			-DCMAKE_BUILD_TYPE=Release \
			-DCMAKE_PREFIX_PATH="${LIBS_ROOT}" \
            -DCMAKE_INSTALL_PREFIX=Release \
            ${BUILD_OPTS_CMAKE} \
	        -DCMAKE_INSTALL_INCLUDEDIR=include \
		    -DCMAKE_TOOLCHAIN_FILE=$APOTHECARY_DIR/toolchains/ios.toolchain.cmake \
			-DPLATFORM=$PLATFORM \
			-DENABLE_BITCODE=OFF \
			-DCMAKE_MACOSX_BUNDLE=OFF \
			-DENABLE_ARC=OFF \
			-DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
			-DENABLE_VISIBILITY=OFF \
			-G Xcode
		cmake --build . --config Release --target install
        cd ..

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
        rm -f CMakeCache.txt *.a *.o *.lib
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
            -DCMAKE_CXX_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            -DCMAKE_C_FLAGS_RELEASE="-DUSE_PTHREADS=1 ${VS_C_FLAGS} ${FLAGS_RELEASE} ${EXCEPTION_FLAGS}" \
            ${BUILD_OPTS_CMAKE} \
            ${CMAKE_WIN_SDK} \
            -A "${PLATFORM}" \
            -G "${GENERATOR_NAME}"

        cmake --build . --config Release --target install

        cd ..
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
		rm -f CMakeCache.txt *.a *.o 
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
		echoWarning "TODO: build $TYPE lib"
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then

		mkdir -p $1/include    
        mkdir -p $1/lib/$TYPE
		mkdir -p $1/lib/$TYPE/$PLATFORM/
		echo "cppy: build_${TYPE}_${PLATFORM}/Release/lib/libcrypto.a"
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libcrypto.a" $1/lib/$TYPE/$PLATFORM/libcrypto.a
		cp -v "build_${TYPE}_${PLATFORM}/Release/lib/libssl.a" $1/lib/$TYPE/$PLATFORM/libssl.a
		cp -Rv "build_${TYPE}_${PLATFORM}/Release/include" $1/
		. "$SECURE_SCRIPT"
		secure $1/lib/$TYPE/$PLATFORM/libssl.a

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

        . "$SECURE_SCRIPT"
		secure $1/lib/$TYPE/$PLATFORM/libssl.lib

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
	
	if [[ "$TYPE" =~ ^(osx|ios|tvos|xros|catos|watchos)$ ]]; then
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
