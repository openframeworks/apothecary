ROOT=$(cd $(dirname $0)/..; pwd -P)
cd $ROOT
TARBALL=openFrameworksLibs_master_linux.tar.bz2
wget http://ci.openframeworks.cc/libs/${TARBALL}
tar xjf ${TARBALL}
rm ${TARBALL}
