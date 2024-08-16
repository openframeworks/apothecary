#!/usr/bin/env /bash
#
# GNU Automake is a tool for automatically generating Makefile.in files compliant with the GNU Coding Standards. Automake requires the use of GNU Autoconf.
# https://www.gnu.org/software/automake/
# requires PERL https://www.perl.org/get.html

FORMULA_TYPES=( "linuxarmv6l", "linuxarmv7l" )
FORMULA_DEPENDS=( )

# define the version
VER=1.16.4
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=https://ftp.gnu.org/gnu/automake/automake
GIT_TAG=v$VER



# download the source code and unpack it into LIB_NAME
function download() {
	pwd
	. "$DOWNLOADER_SCRIPT"
	downloader ${GIT_URL}-$VER.tar.gz
	tar -xf automake-$VER.tar.gz
	mv automake-$VER automake
	rm automake-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	: #noop
}

# executed inside the lib src dir
function build() {
	if [[ "$TYPE" == "linuxarmv6l" || "$TYPE" == "emscripten" ]]; then

		./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.3
		make
		make install
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	if [[ "$TYPE" == "linuxarmv6l" || "$TYPE" == "emscripten" ]]; then
		echo "copy that"
	fi
}

# executed inside the lib src dir
function clean() {
	if [[ "$TYPE" == "linuxarmv6l" || "$TYPE" == "emscripten" ]]; then
		
		make uninstall
		make clean
	fi
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "automake" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
