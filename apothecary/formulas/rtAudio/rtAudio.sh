#!/usr/bin/env bash
#
# RtAudio
# RealTime Audio input/output across Linux, Macintosh OS-X and Windows
# http://www.music.mcgill.ca/~gary/rtaudio/
#
# uses an autotools build system

FORMULA_TYPES=( "osx" "vs" )

#FORMULA_DEPENDS=( "pkg-config" )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
#FORMULA_DEPENDS_MANUAL=1

# define the version
VER=5.2.0

# tools for git use
GIT_URL=https://github.com/thestk/rtaudio
GIT_TAG=master
URL=https://www.music.mcgill.ca/~gary/rtaudio/release/

# download the source code and unpack it into LIB_NAME
function download() {
	#curl -O https://www.music.mcgill.ca/~gary/rtaudio/release/rtaudio-$VER.tar.gz
	wget -nv --no-check-certificate ${URL}/rtaudio-${VER}.tar.gz
	tar -xf rtaudio-${VER}.tar.gz
	mv rtaudio-${VER} rtAudio
	rm rtaudio-${VER}.tar.gz
}

# # prepare the build environment, executed inside the lib src dir
# function prepare() {
# 	# nothing here
# }

# executed inside the lib src dir
function build() {

	# The ./configure / MAKEFILE sequence is broken for OSX, making it
	# impossible to create universal libs in one pass.  As a result, we compile
	# the project manually according to the author's page:
	# https://www.music.mcgill.ca/~gary/rtaudio/compiling.html

	if [ "$TYPE" == "osx" ] ; then
  #       rm -f librtaudio.a
  #       rm -f librtaudio-x86_64

		# # Compile the program
		# /usr/bin/g++ -O2 \
		# 			 -Wall \
		# 			 -fPIC \
		# 			 -stdlib=libc++ \
		# 			 -arch arm64 -arch x86_64 \
		# 			 -Iinclude \
		# 			 -DHAVE_GETTIMEOFDAY \
		# 			 -D__MACOSX_CORE__ \
		# 			 -mmacosx-version-min=${OSX_MIN_SDK_VER} \
		# 			 -c RtAudio.cpp \
		# 			 -o RtAudio.o

		# /usr/bin/ar ruv librtaudio.a RtAudio.o
		# /usr/bin/ranlib librtaudio.a

		mkdir -p build
		cd build
		export CFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER}"
		export LDFLAGS="-arch arm64 -arch x86_64"
    
		cmake .. -G "Unix Makefiles" \
			-DCMAKE_CXX_STANDARD=11 \
			-DCMAKE_CXX_STANDARD_REQUIRED=ON \
			-DCMAKE_CXX_EXTENSION=OFF \
			-DCMAKE_CXX_FLAGS="-fPIC ${CFLAGS}" \
			-DCMAKE_C_FLAGS="-fPIC ${CFLAGS}" \
			-DRTAUDIO_BUILD_SHARED_LIBS=OFF \
			-DRTAUDIO_API_ASIO=OFF \
			-DBUILD_TESTING=OFF
		make
		cd ..

		#/usr/bin/g++ -O2 \
		#			 -Wall \
		#			 -fPIC \
		#			 -stdlib=libc++ \
		#			 -arch x86_64 \
		#			 -Iinclude \
		#			 -DHAVE_GETTIMEOFDAY \
		#			 -D__MACOSX_CORE__ \
		#			 -c RtAudio.cpp \
		#			 -o RtAudio.o

		#/usr/bin/ar ruv librtaudio-x86_64.a RtAudio.o
		#/usr/bin/ranlib librtaudio-x86_64.a

		#lipo -c librtaudio.a librtaudio-x86_64.a -o librtaudio.a

	elif [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		local API="--with-wasapi --with-ds" # asio as well?

		if [ $VS_VER == 15 ] ; then
			if [ $ARCH == 32 ] ; then
				mkdir -p build_vs_32
				cd build_vs_32
				cmake .. -G "Visual Studio $VS_VER" -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|Win32"
				vs-build "rtaudio_static.vcxproj" Build "Debug|Win32"
			elif [ $ARCH == 64 ] ; then
				mkdir -p build_vs_64
				cd build_vs_64
				cmake .. -G "Visual Studio $VS_VER Win64" -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|x64"
				vs-build "rtaudio_static.vcxproj" Build "Debug|x64"
			fi
		else
			if [ $ARCH == 32 ] ; then
				mkdir -p build_vs_32
				cd build_vs_32
				cmake .. -G "Visual Studio $VS_VER" -A Win32 -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|Win32"
				vs-build "rtaudio_static.vcxproj" Build "Debug|Win32"
			elif [ $ARCH == 64 ] ; then
				mkdir -p build_vs_64
				cd build_vs_64
				cmake .. -G "Visual Studio $VS_VER" -A x64 -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|x64"
				vs-build "rtaudio_static.vcxproj" Build "Debug|x64"
			elif [ $ARCH == "ARM" ] ; then
				mkdir -p build_vs_arm
				cd build_vs_arm
				cmake .. -G "Visual Studio $VS_VER" -A ARM -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|ARM"
				vs-build "rtaudio_static.vcxproj" Build "Debug|ARM"
			elif [ $ARCH == "ARM64" ] ; then
				mkdir -p build_vs_arm64
				cd build_vs_arm64
				cmake .. -G "Visual Studio $VS_VER" -A ARM64 -DAUDIO_WINDOWS_WASAPI=ON -DAUDIO_WINDOWS_DS=ON -DAUDIO_WINDOWS_ASIO=ON
				vs-build "rtaudio_static.vcxproj" Build "Release|ARM64"
				vs-build "rtaudio_static.vcxproj" Build "Debug|ARM64"
			fi

		fi

	elif [ "$TYPE" == "msys2" ] ; then
		# Compile the program
		local API="--with-wasapi --with-ds " # asio as well?
		mkdir -p build
		cd build
		cmake .. -G "Unix Makefiles" \
			-DAUDIO_WINDOWS_WASAPI=ON \
			-DAUDIO_WINDOWS_DS=ON \
			-DAUDIO_WINDOWS_ASIO=ON \
			-DBUILD_TESTING=OFF
		make
	fi

	# clean up env vars
	# unset PKG_CONFIG PKG_CONFIG_PATH
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# headers
	mkdir -p $1/include
	cp -v RtAudio.h $1/include
	#cp -v RtError.h $1/include #no longer a part of rtAudio

	# libs
	mkdir -p $1/lib/$TYPE
	if [ "$TYPE" == "vs" ] ; then
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v build_vs_32/Release/rtaudio_static.lib $1/lib/$TYPE/Win32/rtAudio.lib
			cp -v build_vs_32/Debug/rtaudio_static.lib $1/lib/$TYPE/Win32/rtAudioD.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v build_vs_64/Release/rtaudio_static.lib $1/lib/$TYPE/x64/rtAudio.lib
			cp -v build_vs_64/Debug/rtaudio_static.lib $1/lib/$TYPE/x64/rtAudioD.lib
		elif [ $ARCH == "ARM64" ] ; then
			mkdir -p $1/lib/$TYPE/ARM64
			cp -v build_vs_arm64/Release/rtaudio_static.lib $1/lib/$TYPE/ARM64/rtAudio.lib
			cp -v build_vs_arm64/Debug/rtaudio_static.lib $1/lib/$TYPE/ARM64/rtAudioD.lib
		elif [ $ARCH == "ARM" ] ; then
			mkdir -p $1/lib/$TYPE/ARM
			cp -v build_vs_arm/Release/rtaudio_static.lib $1/lib/$TYPE/ARM/rtAudio.lib
			cp -v build_vs_arm/Debug/rtaudio_static.lib $1/lib/$TYPE/ARM/rtAudioD.lib
		fi


	elif [ "$TYPE" == "msys2" ] ; then
		cd build
		ls
		cd ../
		cp -v build/librtaudio.dll.a $1/lib/$TYPE/librtaudio.dll.a

	elif [ "$TYPE" == "osx" ] ; then
		cp -v build/librtaudio.a $1/lib/$TYPE/rtaudio.a
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {

	if [ "$TYPE" == "vs" ] ; then
		vs-clean "rtaudio_static.vcxproj"
	else
		make clean
	fi

	# manually clean dependencies
	#apothecaryDependencies clean
}
