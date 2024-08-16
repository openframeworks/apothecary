#!/usr/bin/env bash
#
# fmod
# https://www.fmod.com
#
# This is not a build script, as fmod is linked as a dynamic library.
# fmod is downloaded as a binary from the fmod.com website and copied
# into the openFrameworks library directory.

FORMULA_TYPES=( "osx" "vs" "linux" "linux64" )
FORMULA_DEPENDS=( )

# define the version
VER=44459
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=
GIT_TAG=

URL=http://openframeworks.cc/ci/fmod

# download the source code and unpack it into LIB_NAME
function download() {


	if [ "$TYPE" == "vs" ]; then
		PKG=fmod_${TYPE}${ARCH}.tar.bz2
		if [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm64ec" ] || [ "$ARCH" == "arm" ]; then
			mkdir fmod
			return 0;
		fi
	else
		PKG=fmod_${TYPE}.tar.bz2
	fi
    . "$DOWNLOADER_SCRIPT"
    downloader "${URL}/${PKG}"
	tar xjf $PKG
	rm "${PKG}"
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: # noop
	# mount install
}

# executed inside the lib src dir
function build() {

	if [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm64ec" ] || [ "$ARCH" == "arm" ]; then
		return 0;
	fi

	if [ "$TYPE" == "osx" ]; then
		cd lib/osx
		install_name_tool -id @executable_path/../Frameworks/libfmod.dylib libfmod.dylib
		cd ../
	fi


}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	cp -r ../fmod/ $1/

	if [ "$TYPE" == "osx" ]; then
		. "$SECURE_SCRIPT"
		secure $1/lib/$TYPE/libfmod.dylib fmod
	fi
}

# executed inside the lib src dir
function clean() {
	: # noop
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "fmod" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
