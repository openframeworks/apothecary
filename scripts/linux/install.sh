#!/usr/bin/env bash
set -e 

# trap any script errors and exit
trap "trapError" ERR

trapError() {
	echo
	echo " ^ Received error ^"
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

sudo add-apt-repository -y ppa:dns/gnu
sudo apt-get update -q
sudo apt-get install gdebi
#wget http://ci.openframeworks.cc/gcc5/cpp-5_5.4.1-2ubuntu1~14.04_amd64.deb
#wget http://ci.openframeworks.cc/gcc5/g++-5_5.4.1-2ubuntu1~14.04_amd64.deb
sudo gdebi -n http://ci.openframeworks.cc/gcc5/cpp-5_5.4.1-2ubuntu1~14.04_amd64.deb
sudo gdebi -n http://ci.openframeworks.cc/gcc5/g++-5_5.4.1-2ubuntu1~14.04_amd64.deb



#sudo apt-get build-dep -y gcc-5
#g++ -v
#apt-get source -y gcc-5
#dpkg-source -x gcc-5_5.4.1-2ubuntu1~14.04.dsc
##dpkg-source -x gcc-5_5.4.1-2ubuntu1~16.04.dsc
#cd gcc-5-5.4.1

#tar -xf gcc-*.tar.xz
#mv gcc-5.4.0 src
#cd src && ./contrib/download_prerequisites
#./configure --prefix=/usr/ \
#-v --with-pkgversion='Ubuntu 5.4.1-2ubuntu1~14.04' --with-bugurl=file:///usr/share/doc/gcc-5/README.Bugs --enable-languages=c,c++ --prefix=/usr --program-suffix=-5 --enable-shared --enable-linker-build-id --libexecdir=/usr/lib --without-included-gettext --enable-threads=posix --libdir=/usr/lib --enable-nls --with-sysroot=/ --enable-clocale=gnu --enable-libstdcxx-debug --enable-libstdcxx-time=yes --with-default-libstdcxx-abi=new --enable-gnu-unique-object --disable-vtable-verify --enable-libmpx --enable-plugin --with-system-zlib --disable-browser-plugin --enable-java-awt=gtk --enable-gtk-cairo -with-arch-directory=amd64 --enable-multiarch --disable-werror --disable-multilib --with-tune=generic --enable-checking=release --build=x86_64-linux-gnu --host=x86_64-linux-gnu --target=x86_64-linux-gnu
#make -j 4 && make install

#sed -i "s/libstdcxx_abi = gcc4-compatible/libstdcxx_abi = new/g" debian/rules.defs
#debian/rules -j4 >> formula.log 2>&1 &
#apothecaryPID=$!
#echoDots $apothecaryPID
#wait $apothecaryPID
#ls *.deb
#cd ..
#ls *.deb

#cd ..
#openssl aes-256-cbc -K $encrypted_aa785955a938_key -iv $encrypted_aa785955a938_iv -in id_rsa.enc -out id_rsa -d
#cp ssh_config ~/.ssh/config
#chmod 600 id_rsa
#echo Uploading libraries
#if [ -e scripts/linux/*.deb ]; then
#    scp -i id_rsa scripts/linux/*.deb tests@ci.openframeworks.cc:libs
#fi

#if [ -e scripts/linux/gcc-5-5.4.1/*.deb ]; then
#    scp -i id_rsa scripts/linux/gcc-5-5.4.1/*.deb tests@ci.openframeworks.cc:libs
#fi

sudo apt-get install -y coreutils realpath libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
sudo apt-get remove -y --purge g++-4.8
sudo apt-get autoremove
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
g++ -v
