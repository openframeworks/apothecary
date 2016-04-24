#! /bin/bash
#
# a helper tool used when compiling applications and libraries
# http://www.freedesktop.org/wiki/Software/pkg-config/

# define the version
VER=0.28

# tools for git use
GIT_URL=http://anongit.freedesktop.org/git/pkg-config.git
GIT_TAG=pkg-config-$VER

# download the source code and unpack it into LIB_NAME
function download() {
	# Skip dowload() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		mkdir pkg-config #apothecary will complain about failed download if it doesn't find this directory
		return
	fi
	
	curl -LO http://pkgconfig.freedesktop.org/releases/pkg-config-$VER.tar.gz
	tar -xf pkg-config-$VER.tar.gz
	mv pkg-config-$VER pkg-config
	rm pkg-config-$VER.tar.gz
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# Skip prepare() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		return
	fi
	
	# generate the configure script if it's not there
	if [ ! -f configure ] ; then
		./autogen.sh
	fi
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "msys2" ] ; then
		install-pkg pkg-config
		return
	fi

	# setting empty flags so it ignores an existing pkg-config install
	# PKG-CONFIG does not need the typical architecture flags because 
	# it is a tool and does not contribute static lib objects to the core
    ./configure --prefix=$BUILD_ROOT_DIR --with-internal-glib GLIB_CFLAGS="" GLIB_LIBS=""

	make
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# Skip copy() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		return
	fi

	# rm link if it exists as this can cause the install to fail 
	if [ -f $BUILD_ROOT_DIR/bin/*-pkg-config ] ; then
		rm $BUILD_ROOT_DIR/bin/*-pkg-config
	fi

	make install
}

# executed inside the lib src dir
function clean() {
	# Skip clean() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		return
	fi
	make uninstall
	make clean
}
