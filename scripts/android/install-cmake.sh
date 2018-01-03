#!/bin/sh
# install CMake for Android builds. Assumes that you have ANDROID_HOME set properly
# Bash scripts are not my thang, so most of these techniques were taken from stackoverflow
PACKAGE_XML_URL="https://github.com/Commit451/android-cmake-installer/releases/download/1.0.0/package.xml"
VERSION_MAJOR="3"
VERSION_MINOR="6"
VERSION_MICRO="3155560"
VERSION=${VERSION_MAJOR}.${VERSION_MINOR}.${VERSION_MICRO}
# can also be darwin or windows (but not really cause .sh)
PLATFORM="linux"
# A POSIX variable
# Reset in case getopts has been used previously in the shell.
OPTIND=1

# Initialize our own variables:
DEBUG=false

# : next to each one that takes variables. It is weird
while getopts ":dp:v:" opt; do
  case $opt in
    d)
      DEBUG=true
      ;;
    p)
      PLATFORM=$OPTARG
      if [[ "$PLATFORM" != "linux" && "$PLATFORM" != "darwin" ]] ; then
        echo "Invalid platform: $PLATFORM"
        echo "Options are \"darwin\" (mac) or \"linux\""
        exit
      fi
      ;;
    v)
      VERSION=$OPTARG
      # splits the version by the . http://stackoverflow.com/a/29903172/895797
      # evaluate command and assign to var http://stackoverflow.com/a/2559087/895797
      VERSION_MAJOR=$(echo "$VERSION" | cut -d "." -f 1)
      VERSION_MINOR=$(echo "$VERSION" | cut -d "." -f 2)
      VERSION_MICRO=$(echo "$VERSION" | cut -d "." -f 3)
      ;;
    \?)
      echo "Invalid option: -$OPTARG"
      ;;
  esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift
if [ "$DEBUG" = true ] ; then
    echo 'Debug enabled. Prepare for lots of printing'
    echo "Platform: $PLATFORM"
    echo "Version: $VERSION"
    echo "Version Major: $VERSION_MAJOR"
    echo "Version Minor: $VERSION_MINOR"
    echo "Version Micro: $VERSION_MICRO"
fi

# This url is not really documented or acknowledged anywhere, it was found through
# some trial and error
NAME="cmake-${VERSION}-${PLATFORM}-x86_64"
wget https://dl.google.com/android/repository/${NAME}.zip

if [ ! -f ${NAME}.zip ]; then
    echo "CMake version not found on server. Make sure your version is formatted like 3.6.1234"
    exit
fi

DIRECTORY=$ANDROID_HOME/cmake/${VERSION}
mkdir -p ${DIRECTORY}
unzip ${NAME}.zip -d ${DIRECTORY}
rm ${NAME}.zip
# Now, in order to trick gradle into believing that we have installed
# through the official means, we need to include a package.xml file with
# the proper values in place
wget ${PACKAGE_XML_URL}
sed -i -- 's/CMAKE_VERSION_COMPLETE/'"$VERSION"'/g' package.xml
sed -i -- 's/CMAKE_VERSION_MAJOR/'"$VERSION_MAJOR"'/g' package.xml
sed -i -- 's/CMAKE_VERSION_MINOR/'"$VERSION_MINOR"'/g' package.xml
sed -i -- 's/CMAKE_VERSION_MICRO/'"$VERSION_MICRO"'/g' package.xml
mv package.xml ${DIRECTORY}

ln -s $DIRECTORY/bin/cmake /usr/local/bin/cmake