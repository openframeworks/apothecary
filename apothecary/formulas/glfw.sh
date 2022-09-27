#!/usr/bin/env bash
#
# GLFW
# creating windows with OpenGL contexts and managing input and events
# http://www.glfw.org
#
# uses a CMake build system

FORMULA_TYPES=( "osx" "vs" )

# define the version by branch  
# VER=2018-cmake-fix
# tools for git use
# GIT_URL=https://github.com/ofTheo/glfw/
GIT_URL=https://github.com/glfw/glfw/
# VER=master
VER=3.3.8
GIT_BRANCH=$VER

# download the source code and unpack it into LIB_NAME
function download() {
	 echo "Running: git clone --branch ${GIT_BRANCH} ${GIT_URL}"
     git clone --branch ${GIT_BRANCH} ${GIT_URL} --depth 1
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
}

# executed inside the lib src dir
function build() {
	rm -f CMakeCache.txt

	if [ "$TYPE" == "vs" ] ; then
		unset TMP
		unset TEMP
		if [ $ARCH == 32 ] ; then
			mkdir -p build_vs_32
			cd build_vs_32
			cmake .. -G "Visual Studio $VS_VER"
			vs-build "GLFW.sln"
		elif [ $ARCH == 64 ] ; then
			mkdir -p build_vs_64
			cd build_vs_64
			cmake .. -G "Visual Studio $VS_VER $VS_YEAR" -A x64
			vs-build "GLFW.sln" Build "Release|x64"
		fi
	else
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            EXTRA_CONFIG="-DGLFW_USE_EGL=1 -DGLFW_CLIENT_LIBRARY=glesv2 -DCMAKE_LIBRARY_PATH=$SYSROOT/usr/lib -DCMAKE_INCLUDE_PATH=$SYSROOT/usr/include"
        else
            EXTRA_CONFIG=" "
        fi
		# *nix build system

		mkdir -p build
		cd build

		# OS X needs both arches specified to be universal
		# for some reason it doesn't build if passed through EXTRA_CONFIG so have do break it up into a separate cmake call
		if [ "$TYPE" == "osx" ] ; then
			cmake .. -DGLFW_BUILD_DOCS=OFF \
					-DGLFW_BUILD_TESTS=OFF \
					-DGLFW_BUILD_EXAMPLES=OFF \
					-DBUILD_SHARED_LIBS=OFF \
					-DCMAKE_BUILD_TYPE=Release \
                    -DCMAKE_OSX_DEPLOYMENT_TARGET=${OSX_MIN_SDK_VER} \
                    -DCMAKE_C_FLAGS="-arch arm64 -arch x86_64" \
					$EXTRA_CONFIG
		else
			cmake .. -DGLFW_BUILD_DOCS=OFF \
					-DGLFW_BUILD_TESTS=OFF \
					-DGLFW_BUILD_EXAMPLES=OFF \
					-DBUILD_SHARED_LIBS=OFF \
					-DCMAKE_BUILD_TYPE=Release
					$EXTRA_CONFIG
		fi

 		make clean
 		make -j${PARALLEL_MAKE}
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# prepare headers directory if needed
	mkdir -p $1/include/GLFW

	# prepare libs directory if needed
	mkdir -p $1/lib/$TYPE

	if [ "$TYPE" == "vs" ] ; then
		cp -Rv include/* $1/include
		if [ $ARCH == 32 ] ; then
			mkdir -p $1/lib/$TYPE/Win32
			cp -v build_vs_32/src/Release/glfw3.lib $1/lib/$TYPE/Win32/glfw3.lib
		elif [ $ARCH == 64 ] ; then
			mkdir -p $1/lib/$TYPE/x64
			cp -v build_vs_64/src/Release/glfw3.lib $1/lib/$TYPE/x64/glfw3.lib
		fi
	elif [ "$TYPE" == "osx" ]; then
		# Standard *nix style copy.
		# copy headers
		cp -Rv include/GLFW/* $1/include/GLFW/
		# copy lib
		cp -Rv build/src/libglfw3.a $1/lib/$TYPE/glfw3.a
	fi

	# copy license file
	rm -rf $1/license # remove any older files if exists
	mkdir -p $1/license
	cp -v LICENSE.md $1/license/
}

# executed inside the lib src dir
function clean() {
	if [ "$TYPE" == "vs" ] ; then
		rm -f *.lib
	else
		make clean
	fi
}
