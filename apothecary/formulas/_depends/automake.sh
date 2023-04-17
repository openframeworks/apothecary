#!/usr/bin/env /bash
#
# GNU Automake is a tool for automatically generating Makefile.in files compliant with the GNU Coding Standards. Automake requires the use of GNU Autoconf.
# https://www.gnu.org/software/automake/
# requires PERL https://www.perl.org/get.html


# define the version
VER=1.16.4

# tools for git use
GIT_URL=https://ftp.gnu.org/gnu/automake/automake
GIT_TAG=v$VER

FORMULA_TYPES=( "linuxarmv6l", "linuxarmv7l", "emscripten" )

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
