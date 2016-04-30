#! /bin/bash
#
# Fontconfig
# 


FORMULA_TYPES=( "msys2" )
# define the version
VER=0.32.4


# download the source code and unpack it into LIB_NAME
function download() {
	# Skip dowload() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		mkdir fontconfig #apothecary will complain about failed download if it doesn't find this directory
		return
	fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {
	# Skip prepare() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		return
	fi
}

# executed inside the lib src dir
function build() {
	if [ "$TYPE" == "msys2" ] ; then
		install-pkg fontconfig
		return
	fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {
	# Copy package manager installed files
	if [ "$TYPE" == "msys2" ] ; then
		local PREFIX_DIR=/mingw32
		local LIB_DIR=$TYPE/Win32
		if [ $ARCH == 64 ] ; then 
			PREFIX_DIR=/mingw64
			LIB_DIR=$TYPE/x64
		fi
		
		#Copy headers
		mkdir -p $1/include
		cp -rv ${PREFIX_DIR}/include/fontconfig/* $1/include/
		
		#copy libs
		mkdir -p $1/$LIB_DIR
		cp -rv ${PREFIX_DIR}/lib/libfontconfig.a $1/$LIB_DIR/
		cp -rv ${PREFIX_DIR}/lib/libfontconfig.dll.a $1/$LIB_DIR/
		
		#copys dlls
		mkdir -p $1/../export/$LIB_DIR
		cp -rv ${PREFIX_DIR}/bin/libfontconfig-1.dll $1/../export/$LIB_DIR/
		
		#copy licence
		rm -rf $1/license
		mkdir -p $1/license
		cp -rv ${PREFIX_DIR}/share/licenses/fontconfig/* $1/license/
		return
	fi
}

# executed inside the lib src dir
function clean() {
	# Skip clean() for "msys2"
	if [ "$TYPE" == "msys2" ] ; then
		return
	fi
}
