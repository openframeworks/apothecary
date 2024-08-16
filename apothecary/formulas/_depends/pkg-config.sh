#!/usr/bin/env /bash
#
# a helper tool used when compiling applications and libraries
# http://www.freedesktop.org/wiki/Software/pkg-config/

# define the version
VER=0.29.2
BUILD_ID=1
DEFINES=""

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/pkg-config.git
GIT_TAG=pkg-config-$VER
URL="https://pkgconfig.freedesktop.org/releases"

FORMULA_TYPES=(  )

# download the source code and unpack it into LIB_NAME
function download() {
	curl -LO ${URL}/pkg-config-$VER.tar.gz
	tar -xf pkg-config-$VER.tar.gz
	# if [ "$CHECKSHA" != "$SHA1" ] ; then
 #    echoError "ERROR! SHA did not Verify: [$CHECKSHA] SHA on Record:[$SHA1] - Developer has not updated SHA or Man in the Middle Attack"
 #    else
 #        echo "SHA for Download Verified Successfully: [$CHECKSHA] SHA on Record:[$SHA1]"
 #    fi
	mv pkg-config-$VER pkg-config
	rm pkg-config-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# generate the configure script if it's not there
	if [ ! -f configure ] ; then
		./autogen.sh
	fi
}

# executed inside the lib src dir
function build() {

	echo "build pkg-config"
	# setting empty flags so it ignores an existing pkg-config install
	# PKG-CONFIG does not need the typical architecture flags because
	# it is a tool and does not contribute static lib objects to the core
    ./configure --prefix=$BUILD_ROOT_DIR --with-internal-glib GLIB_CFLAGS="" GLIB_LIBS=""

	make -j${PARALLEL_MAKE}
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

	# rm link if it exists as this can cause the install to fail
	if [ -f $BUILD_ROOT_DIR/bin/*-pkg-config ] ; then
		rm $BUILD_ROOT_DIR/bin/*-pkg-config
	fi

	make install

	echo "copy/install pkg-config"
}

# executed inside the lib src dir
function clean() {
	make uninstall
	make clean
}


function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "pkg-config" ${ARCH} ${VER} "$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM" ${PLATFORM} )
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        echo 0
    fi
}
