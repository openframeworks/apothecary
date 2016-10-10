sed -e 

# trap any script errors and exit
trap "trapError" ERR

trapError() {
	echo
	echo " ^ Received error ^"
	cat formula.log
	if [ "$formula_name" == "boost" ]; then
	    cat $APOTHECARY_PATH/build/boost/bootstrap.log
	fi
    if [ -f $APOTHECARY_PATH/build/$formula_name/config.log ]; then
        cat $APOTHECARY_PATH/build/$formula_name/config.log
    fi
	exit 1
}

isRunning(){
    if [ “$(uname)” == “Linux” ]; then
		if [ -d /proc/$1 ]; then
	    	return 0
        else
            return 1
        fi
    else
        number=$(ps aux | sed -E "s/[^ ]* +([^ ]*).*/\1/g" | grep ^$1$ | wc -l)

        if [ $number -gt 0 ]; then
            return 0;
        else
            return 1;
        fi
    fi
}

echoDots(){
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return;
            fi
            sleep 2
        done
        printf "\r                    "
        printf "\r"
    done
}

sudo add-apt-repository -y -s ppa:dns/gnu
sudo add-apt-repository -y -s ppa:ubuntu-toolchain-r/test
sudo apt-get update -q

g++ -v


sudo apt-get build-dep -y gcc-5
apt-get source -y gcc-5
dpkg-source -x gcc-5_5.4.1-2ubuntu1~14.04.dsc
#dpkg-source -x gcc-5_5.4.1-2ubuntu1~16.04.dsc
cd gcc-5-5.4.1

#tar -xf gcc-*.tar.xz
#mv gcc-5.4.0 src
#cd src && ./contrib/download_prerequisites
#./configure --prefix=/usr/ \
#-v --with-pkgversion='Ubuntu 5.4.1-2ubuntu1~14.04' --with-bugurl=file:///usr/share/doc/gcc-5/README.Bugs --enable-languages=c,c++ --prefix=/usr --program-suffix=-5 --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --with-system-zlib --disable-browser-plugin --enable-java-awt=gtk --enable-gtk-cairo -with-arch-directory=amd64 --enable-multiarch --disable-werror --disable-multilib --with-tune=generic --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu
#make -j 4 && make install

sed -i "s/libstdcxx_abi = gcc4-compatible/libstdcxx_abi = new/g" debian/rules.defs
debian/rules -j4 >> formula.log 2>&1 &
apothecaryPID=$!
echoDots $apothecaryPID
wait $apothecaryPID
ls *.deb

sudo apt-get install -y coreutils realpath libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
sudo apt-get remove -y --purge g++-4.8
sudo apt-get autoremove
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
g++ -v
