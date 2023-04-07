#!/usr/bin/env bash
#
# Poco
# C++ with Batteries Included
# http://pocoproject.org/
#
# uses an autotools build system,
# specify specfic build configs in poco/config using ./configure --config=NAME

# define the version
VER=1.11.1-release

# tools for git use
GIT_URL=https://github.com/pocoproject/poco
GIT_TAG=poco-${VER}

FORMULA_TYPES=( "osx" "ios" "tvos" "emscripten" "vs" "linux" "linux64" )

#dependencies
FORMULA_DEPENDS=( "openssl" )

# tell apothecary we want to manually call the dependency commands
# as we set some env vars for osx the depends need to know about
FORMULA_DEPENDS_MANUAL=1

# For Poco Builds, we omit both Data/MySQL and Data/ODBC because they require
# 3rd Party libraries.  See https://github.com/pocoproject/poco/blob/develop/README
# for more information.

SHA=

# download the source code and unpack it into LIB_NAME
function download() {
    if [ "$SHA" == "" ] ; then
        echo "SHA=="" Using $GIT_URL with GIT_TAG=$GIT_TAG"
        curl -Lk $GIT_URL/archive/$GIT_TAG.tar.gz -o poco-$GIT_TAG.tar.gz
        tar -xf poco-$GIT_TAG.tar.gz
        mv poco-$GIT_TAG poco
        rm poco*.tar.gz
    else
        echo "$GIT_URL - Using SHA=$SHA"
        git clone $GIT_URL -b poco-$VER
    fi
}

# prepare the build environment, executed inside the lib src dir
function prepare() {

    if [ "$SHA" != "" ] ; then
        echo "Setting git repo to SHA=$SHA"
        git reset --hard $SHA
    fi

    if [ "$TYPE" != "linux" ] && [ "$TYPE" != "ios" ] && [ "$TYPE" != "tvos" ] && [ $FORMULA_DEPENDS_MANUAL -ne 1 ]; then
        # manually prepare dependencies
        apothecaryDependencies download
        apothecaryDependencies prepare
        # Build and copy all dependencies in preparation
        apothecaryDepend build openssl
        apothecaryDepend copy openssl
    fi

    # make backups of the ios config files since we need to edit them
    if [[ "$TYPE" == "ios" ||  "$TYPE" == "tvos" ]] ; then
        mkdir -p lib/$TYPE
        mkdir -p lib/iPhoneOS

        if [[ "$TYPE" == "tvos" ]]; then
            cp $FORMULA_DIR/AppleTV build/config/AppleTV
            cp $FORMULA_DIR/AppleTVSimulator build/config/AppleTVSimulator
        fi

        # fix using sed i686 reference and allow overloading variable
        sed -i "" "s|POCO_TARGET_OSARCH.* = .*|POCO_TARGET_OSARCH ?= x86_64|" build/config/iPhoneSimulator-clang-libc++
        sed -i "" "s|OSFLAGS            = -arch|OSFLAGS            ?= -arch arm64 -arch|" build/config/iPhoneSimulator-clang-libc++
        sed -i "" "s|STATICOPT_CC    =|STATICOPT_CC    ?= -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|STATICOPT_CXX   =|STATICOPT_CXX   ?= -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|OSFLAGS                 = -arch|OSFLAGS                ?= -arch|" build/config/iPhone
        sed -i "" "s|RELEASEOPT_CC   = -DNDEBUG -O2|RELEASEOPT_CC   =  -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone
        sed -i "" "s|RELEASEOPT_CXX  = -DNDEBUG -O |RELEASEOPT_CXX  =  -DNDEBUG -DPOCO_ENABLE_CPP11 -Os -fPIC|" build/config/iPhone

        # sed -i .tmp "s|EVP_CIPHER_CTX_cleanup(_pContext);||g" Crypto/src/CipherImpl.cpp
        # sed -i -e "s|#include <openssl/evp.h>|#include <openssl/evp.h>\n#include <openssl/bn.h>|" Crypto/src/X509Certificate.cpp

        # cp build/rules/compile build/rules/compile.orig
        # Fix for making debug and release, making just release
        sed -i "" "s|all_static: static_debug static_release|all_static: static_release|" build/rules/compile


    elif [ "$TYPE" == "vs" ] ; then
        #change the build win cmd file for vs2015 compatibility
        CURRENTPATH=`pwd`
        
        #doing this for VS 2019 as we have to pass in the SSL path and so it requires a modified buildwin.cmd
        rm buildwin.cmd
        cp -v $FORMULA_DIR/buildwin.cmd $CURRENTPATH


        # Patch the components to exclude those that we aren't using.
        cp -v $FORMULA_DIR/components $CURRENTPATH

        # Locate the path of the openssl libs distributed with openFrameworks.
        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

        # get the absolute path to the included openssl libs
        local OF_LIBS_OPENSSL_ABS_PATH=$(cd $OF_LIBS_OPENSSL; pwd)

        # convert the absolute path from unix to windows
        #local OPENSSL_DIR=$(echo $OF_LIBS_OPENSSL_ABS_PATH | sed 's/^\///' | sed 's/\//\\/g' | sed 's/^./\0:/')

        # escape windows slashes and a few common escape sequences before passing to sed
        #local OPENSSL_DIR=$(echo $OPENSSL_DIR | sed 's/\\/\\\\\\/g' | sed 's/\\\U/\\\\U/g' | sed 's/\\\l/\\\\l/g')
        export OPENSSL_DIR="$(cygpath -w $OF_LIBS_OPENSSL_ABS_PATH)"
        # export ESCAPED_OPENSSL_DIR="$(echo $OPENSSL_DIR  | sed 's/\\/\\\\/g' | sed 's/\:/\\:/g')"
        echo $OPENSSL_DIR

        # # replace OPENSSL_DIR=C:\OpenSSL with our OPENSSL_DIR
        # sed -i.tmp "s|C:\\\OpenSSL|$ESCAPED_OPENSSL_DIR|g" buildwin.cmd

        # # replace OPENSSL_LIB=%OPENSSL_DIR%\lib;%OPENSSL_DIR%\lib\VC with OPENSSL_LIB=%OPENSSL_DIR%\lib\vs
        # sed -i.tmp "s|%OPENSSL_DIR%\\\lib;.*|%OPENSSL_DIR%\\\lib\\\vs|g" buildwin.cmd

        sed -i.tmp "s|set OPENSSL_DIR=C:\\\OpenSSL||g" buildwin.cmd
    elif [ "$TYPE" == "android" ] ; then
        installAndroidToolchain
        if patch -p0 -u -N --dry-run --silent < $FORMULA_DIR/android.patch 2>/dev/null ; then
            patch -p0 -u < $FORMULA_DIR/android.patch
        fi
        cp $FORMULA_DIR/Android build/config/Android
    elif [ "$TYPE" == "linux" -o "$TYPE" == "linux64" ] ; then
        cp $FORMULA_DIR/Linux build/config/Linux
    fi

}

# executed inside the lib src dir
function build() {
    local BUILD_OPTS="--no-tests --no-samples --static --omit=CppUnit,CppUnit/WinTestRunner,Data,Data/SQLite,Data/ODBC,Data/MySQL,PageCompiler,PageCompiler/File2Page,CppParser,PDF,PocoDoc,ProGen,MongoDB"
    if [ "$TYPE" == "osx" ] ; then
        CURRENTPATH=`pwd`
        echo "--------------------"
        echo "Making Poco-${VER}"
        echo "--------------------"
        echo "Configuring for universal arm64 and x86_64 libc++ ..."

        # Locate the path of the openssl libs distributed with openFrameworks.
        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"
        local OF_LIBS_OPENSSL_ABS_PATH=$(cd $(dirname $OF_LIBS_OPENSSL); pwd)/$(basename $OF_LIBS_OPENSSL)

        local OPENSSL_INCLUDE=$OF_LIBS_OPENSSL_ABS_PATH/include
        local OPENSSL_LIBS=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE
        
        local BUILD_OPTS="$BUILD_OPTS --include-path=$OPENSSL_INCLUDE --library-path=$OPENSSL_LIBS"
        
        sed -i '' 's/DEFAULT_TARGET = all_static/DEFAULT_TARGET = static_release/g' build/rules/global
        local SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)

        export ARCHFLAGS="-arch arm64 -arch x86_64 -mmacosx-version-min=${OSX_MIN_SDK_VER} -isysroot${SDK_PATH}"
        ./configure $BUILD_OPTS --config=Darwin-clang-libc++ \
            --prefix=$BUILD_DIR/poco/install/$TYPE
            
        make -j${PARALLEL_MAKE}
        make install
        rm -f install/$TYPE/lib/*d.a
    elif [ "$TYPE" == "vs" ] ; then
        unset TMP
        unset TEMP

        if [[ $VS_VER -gt 14 ]]; then

                if [ $ARCH == 32 ] ; then
                    echo "" > with_env_poco.bat # cleanup temporary bat file
                    echo "call \"$VS_VARS_PATH\"" >>  with_env_poco.bat
                    echo "buildwin.cmd ${VS_VER}0 upgrade static_md both Win32 nosamples notests" >>  with_env_poco.bat
                    cmd.exe //C "call with_env_poco.bat"

                    echo "" > with_env_poco.bat # cleanup temporary bat file
                    echo "call \"$VS_VARS_PATH\"" >>  with_env_poco.bat
                    echo "buildwin.cmd ${VS_VER}0 build static_md both Win32 nosamples notests" >> with_env_poco.bat
                    cmd.exe //C "call with_env_poco.bat"


                elif [ $ARCH == 64 ] ; then
                    
                    echo "" > with_env_poco.bat # cleanup temporary bat file
                    echo "call \"$VS_VARS_PATH\" x64" >>  with_env_poco.bat
                    echo "buildwin.cmd ${VS_VER}0 build static_md both x64 nosamples notests" >>  with_env_poco.bat
                    cat with_env_poco.bat
                    cmd.exe //C "call with_env_poco.bat"

                fi

            else

                if [ $ARCH == 32 ] ; then
                    cmd.exe //c "call \"%VS${VS_VER}0COMNTOOLS%vsvars32.bat\" && buildwin.cmd ${VS_VER}0 upgrade static_md both Win32 nosamples notests"
                    cmd.exe //c "call \"%VS${VS_VER}0COMNTOOLS%vsvars32.bat\" && buildwin.cmd ${VS_VER}0 build static_md both Win32 nosamples notests"
                elif [ $ARCH == 64 ] ; then
                    cmd.exe //c "call \"%VS${VS_VER}0COMNTOOLS%..\\..\\${VS_64_BIT_ENV}\" amd64 && buildwin.cmd ${VS_VER}0 upgrade static_md both x64 nosamples notests"
                    cmd.exe //c "call \"%VS${VS_VER}0COMNTOOLS%..\\..\\${VS_64_BIT_ENV}\" amd64 && buildwin.cmd ${VS_VER}0 build static_md both x64 nosamples notests"
                fi
        fi

    elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        set -e
        SDKVERSION=""
        if [ "${TYPE}" == "tvos" ]; then
            SDKVERSION=`xcrun -sdk appletvos --show-sdk-version`
        elif [ "$TYPE" == "ios" ]; then
            SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`
        fi
        CURRENTPATH=`pwd`

        DEVELOPER=$XCODE_DEV_ROOT
        TOOLCHAIN=${DEVELOPER}/Toolchains/XcodeDefault.xctoolchain
        VERSION=$VER

        local IOS_ARCHS
        if [ "${TYPE}" == "tvos" ]; then
            IOS_ARCHS="x86_64 arm64"
        elif [ "$TYPE" == "ios" ]; then
            IOS_ARCHS="x86_64 armv7 arm64" #armv7s
        fi

        echo "--------------------"
        echo $CURRENTPATH

        # Validate environment
        case $XCODE_DEV_ROOT in
             *\ * )
                   echo "Your Xcode path contains whitespaces, which is not supported."
                   exit 1
                  ;;
        esac
        case $CURRENTPATH in
             *\ * )
                   echo "Your path contains whitespaces, which is not supported by 'make install'."
                   exit 1
                  ;;
        esac

        echo "------------"
        # To Fix: global:62: *** Current working directory not under $PROJECT_BASE.  Stop. make
        echo "Note: For Poco, make sure to call it with lowercase poco name: ./apothecary -t ios update poco"
        echo "----------"

        local BUILD_POCO_CONFIG_IPHONE=iPhone-clang-libc++
        local BUILD_POCO_CONFIG_SIMULATOR=iPhoneSimulator-clang-libc++

        # Locate the path of the openssl libs distributed with openFrameworks.
        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

        # get the absolute path to the included openssl libs
        local OF_LIBS_OPENSSL_ABS_PATH=$(cd $(dirname $OF_LIBS_OPENSSL); pwd)/$(basename $OF_LIBS_OPENSSL)

        local OPENSSL_INCLUDE=$OF_LIBS_OPENSSL_ABS_PATH/include
        local OPENSSL_LIBS=$OF_LIBS_OPENSSL_ABS_PATH/lib/$TYPE

        local BUILD_OPTS="$BUILD_OPTS --include-path=$OPENSSL_INCLUDE --library-path=$OPENSSL_LIBS"

        STATICOPT_CC=-fPIC
        STATICOPT_CXX=-fPIC
  
        sed -i '' 's/DEFAULT_TARGET = all_static/DEFAULT_TARGET = static_release/g' build/rules/global

        # loop through architectures! yay for loops!
        for IOS_ARCH in ${IOS_ARCHS}
        do
            MIN_IOS_VERSION=$IOS_MIN_SDK_VER
            # min iOS version for arm64 is iOS 7

            if [[ "${IOS_ARCH}" == "arm64" || "${IOS_ARCH}" == "x86_64" ]]; then
                MIN_IOS_VERSION=7.0 # 7.0 as this is the minimum for these architectures
            elif [ "${IOS_ARCH}" == "i386" ]; then
                MIN_IOS_VERSION=7.0 # 6.0 to prevent start linking errors
            fi
            export IPHONE_SDK_VERSION_MIN=$IOS_MIN_SDK_VER

            export POCO_TARGET_OSARCH=$IOS_ARCH

            MIN_TYPE=-miphoneos-version-min=

            if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
            then
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVSimulator"
                    BUILD_POCO_CONFIG="AppleTVSimulator"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneSimulator"
                    BUILD_POCO_CONFIG=$BUILD_POCO_CONFIG_SIMULATOR
                fi
            else
                if [ "${TYPE}" == "tvos" ]; then
                    PLATFORM="AppleTVOS"
                    BUILD_POCO_CONFIG="AppleTV"
                elif [ "$TYPE" == "ios" ]; then
                    PLATFORM="iPhoneOS"
                    BUILD_POCO_CONFIG=$BUILD_POCO_CONFIG_IPHONE
                fi
            fi

            if [ "${TYPE}" == "tvos" ]; then
                MIN_TYPE=-mtvos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mtvos-simulator-version-min=
                fi
            elif [ "$TYPE" == "ios" ]; then
                MIN_TYPE=-miphoneos-version-min=
                if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]]; then
                    MIN_TYPE=-mios-simulator-version-min=
                fi
            fi

            BITCODE=""
            NOFORK=""
            if [[ "$TYPE" == "tvos" ]]; then
                BITCODE=-fembed-bitcode;
                MIN_IOS_VERSION=9.0
                NOFORK="-DPOCO_NO_FORK_EXEC"
            fi

            export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
            export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
            export BUILD_TOOLS="${DEVELOPER}"

            mkdir -p "$CURRENTPATH/build/$TYPE/$IOS_ARCH"
            set +e

            if [[ "${IOS_ARCH}" == "i386" || "${IOS_ARCH}" == "x86_64" ]];
            then
                export OSFLAGS="-arch $POCO_TARGET_OSARCH $BITCODE -DNDEBUG $NOFORK -fPIC -DPOCO_ENABLE_CPP11 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} $MIN_TYPE$MIN_IOS_VERSION"
            else
                export OSFLAGS="-arch $POCO_TARGET_OSARCH $BITCODE -DNDEBUG $NOFORK -fPIC -DPOCO_ENABLE_CPP11 -isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} $MIN_TYPE$MIN_IOS_VERSION"
            fi
            echo "--------------------"
            echo "Making Poco-${VER} for ${PLATFORM} ${SDKVERSION} ${IOS_ARCH} : iOS Minimum=$MIN_IOS_VERSION"
            echo "--------------------"
      
            echo "Configuring for ${IOS_ARCH} ..."
            ./configure $BUILD_OPTS --config=$BUILD_POCO_CONFIG

            echo "--------------------"
            echo "Running make for ${IOS_ARCH}"
            make -j${PARALLEL_MAKE}
            unset POCO_TARGET_OSARCH IPHONE_SDK_VERSION_MIN OSFLAGS
            unset CROSS_TOP CROSS_SDK BUILD_TOOLS

            echo "--------------------"

        done

        if [[ "${TYPE}" == "tvos" ]] ; then
            cd lib/AppleTVOS
            # link into universal lib, strip "lib" from filename
            local lib
            for lib in $( ls -1 arm64) ; do
                local renamedLib=$(echo $lib | sed 's|lib||')
                if [ ! -e $renamedLib ] ; then
                        lipo -extract x86_64 ../AppleTVSimulator/x86_64/$lib -o ../AppleTVSimulator/x86_64/$lib
                        lipo -c arm64/$lib \
                        ../AppleTVSimulator/x86_64/$lib \
                        -o ../tvos/$renamedLib
                fi
            done
        elif [[ "$TYPE" == "ios" ]]; then
            cd lib/iPhoneOS
            # link into universal lib, strip "lib" from filename
            local lib
            for lib in $( ls -1 arm64) ; do
                local renamedLib=$(echo $lib | sed 's|lib||')
                if [ ! -e $renamedLib ] ; then
                        lipo -c armv7/$lib \
                        arm64/$lib \
                        ../iPhoneSimulator/x86_64/$lib \
                        -o ../ios/$renamedLib
                fi
            done
        fi


        cd ../../

        if [[ "$TYPE" == "ios" ]]; then
            echo "--------------------"
            echo "Stripping any lingering symbols"

            cd lib/$TYPE
            local TOBESTRIPPED
            for TOBESTRIPPED in $( ls -1) ; do
                strip -x $TOBESTRIPPED
            done
            cd ../../
        fi

        echo "Completed."

    elif [ "$TYPE" == "android" ] ; then
        local OLD_PATH=$PATH

        export PATH=$BUILD_DIR/Toolchains/Android/$ARCH/bin:$OLD_PATH

        local OF_LIBS_OPENSSL="$LIBS_DIR/openssl/"

        # get the absolute path to the included openssl libs
        local OF_LIBS_OPENSSL_ABS_PATH=$(cd $(dirname $OF_LIBS_OPENSSL); pwd)/$(basename $OF_LIBS_OPENSSL)
        local OPENSSL_INCLUDE=$OF_LIBS_OPENSSL_ABS_PATH/include
        local OPENSSL_LIBS=$OF_LIBS_OPENSSL_ABS_PATH/lib/

        source ../../android_configure.sh $ABI
        #export CXX=clang++
        ./configure $BUILD_OPTS \
                    --include-path=$OPENSSL_INCLUDE \
                    --library-path=$OPENSSL_LIBS/$ABI \
                    --config=Android
        make clean ANDROID_ABI=$ABI
        make -j${PARALLEL_MAKE} ANDROID_ABI=$ABI
        rm -f lib/Android/$ABI/*d.a

        export PATH=$OLD_PATH

    elif [ "$TYPE" == "linux" ] || [ "$TYPE" == "linux64" ] ; then
        ./configure $BUILD_OPTS
        make -j${PARALLEL_MAKE}
        # delete debug builds
        rm -f lib/Linux/$(uname -m)/*d.a
    elif [ "$TYPE" == "linuxarmv6l" ] || [ "$TYPE" == "linuxarmv7l" ]; then
        if [ $CROSSCOMPILING -eq 1 ]; then
            source ../../${TYPE}_configure.sh
            export CROSS_COMPILE=$TOOLCHAIN_ROOT/bin/$TOOLCHAIN_PREFIX-
            export LIBRARY_PATH="$SYSROOT/usr/lib $SYSROOT/usr/lib/$TOOLCHAIN_PREFIX"
        fi
        ./configure $BUILD_OPTS \
            --library-path="$LIBRARY_PATH" \
            --cflags="$CFLAGS" \
            --prefix=$BUILD_DIR/poco/install/$TYPE
        make -j${PARALLEL_MAKE}
        make install
        # delete debug builds
        rm -f install/$TYPE/lib/*d.a
    else
        echoWarning "TODO: build $TYPE lib"
    fi
}

# executed inside the lib src dir, first arg $1 is the dest libs dir root
function copy() {

    # headers
    mkdir -pv $1/include/Poco
    cp -Rv Crypto/include/Poco/Crypto $1/include/Poco
    cp -Rv Data/include/Poco/Data $1/include/Poco
    cp -Rv Data/SQLite/include/Poco/Data $1/include/Poco
    cp -Rv Foundation/include/Poco/* $1/include/Poco
    cp -Rv JSON/include/Poco/JSON $1/include/Poco
    cp -Rv MongoDB/include/Poco/MongoDB $1/include/Poco
    cp -Rv Net/include/Poco/Net $1/include/Poco
    cp -Rv NetSSL_OpenSSL/include/Poco/Net/* $1/include/Poco/Net
    cp -Rv SevenZip/include/Poco/SevenZip $1/include/Poco
    cp -Rv Util/include/Poco/Util $1/include/Poco
    cp -Rv XML/include/Poco/* $1/include/Poco
    cp -Rv Zip/include/Poco/Zip $1/include/Poco

  rm -rf $1/lib/$TYPE
  mkdir -p $1/lib/$TYPE

    # libs
    if [ "$TYPE" == "osx" ] ; then
        for lib in install/$TYPE/lib/*.a; do
            dstlib=$(basename $lib | sed "s/lib\(.*\)/\1/")
            cp -v $lib $1/lib/$TYPE/$dstlib
        done
    elif [[ "$TYPE" == "ios" || "$TYPE" == "tvos" ]] ; then
        cp -v lib/$TYPE/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "vs" ] ; then
        if [ $ARCH == 32 ] ; then
            mkdir -p $1/lib/$TYPE/Win32/Debug
            cp -v lib/*mdd.lib $1/lib/$TYPE/Win32/Debug/

            mkdir -p $1/lib/$TYPE/Win32/Release
            cp -v lib/*md.lib $1/lib/$TYPE/Win32/Release/
        elif [ $ARCH == 64 ] ; then
            mkdir -p $1/lib/$TYPE/x64/Debug
            cp -v lib64/*mdd.lib $1/lib/$TYPE/x64/Debug/

            mkdir -p $1/lib/$TYPE/x64/Release
            cp -v lib64/*md.lib $1/lib/$TYPE/x64/Release
        fi

    elif [ "$TYPE" == "msys2" ] ; then
        cp -vf lib/MinGW/i686/*.a $1/lib/$TYPE
        #cp -vf lib/MinGW/x86_64/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "linux" ] ; then
        cp -v lib/Linux/$(uname -m)/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "linux64" ] ; then
        cp -v lib/Linux/x86_64/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "linuxarmv6l" ] ; then
        cp -v install/$TYPE/lib/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "linuxarmv7l" ] ; then
        cp -v install/$TYPE/lib/*.a $1/lib/$TYPE
    elif [ "$TYPE" == "android" ] ; then
        rm -rf $1/lib/$TYPE/$ABI
        mkdir -p $1/lib/$TYPE/$ABI
        cp -v lib/Android/$ABI/*.a $1/lib/$TYPE/$ABI
    else
        echoWarning "TODO: copy $TYPE lib"
    fi

    # copy license file
    echo "remove license"
    rm -rf $1/license # remove any older files if exists
    echo "create license dir"
    mkdir -p $1/license
    echo "copy license"
    cp -v LICENSE $1/license/
}

# executed inside the lib src dir
function clean() {

    if [ "$TYPE" == "vs" ] ; then
        cmd //c buildwin.cmd ${VS_VER}0 clean static_md both Win32 nosamples notests
        cmd //c buildwin.cmd ${VS_VER}0 clean static_md both x64 nosamples notests
        #vs-clean "Poco.sln"
    elif [ "$TYPE" == "android" ] ; then
        export PATH=$PATH:$ANDROID_TOOLCHAIN_ANDROIDEABI/bin:$ANDROID_TOOLCHAIN_X86/bin
        make clean ANDROID_ABI=armeabi
        make clean ANDROID_ABI=armeabi-v7a
        make clean ANDROID_ABI=x86
        unset PATH
    else
        make clean
    fi
}

