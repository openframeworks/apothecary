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

if [ "$OPT" == "gcc4" ]; then
    sudo add-apt-repository -y ppa:dns/gnu
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update -q
    sudo apt-get install -y gperf coreutils libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
    sudo apt-get install gcc-4.9 g++-4.9
    #needed because github actions defaults to gcc 5
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.9 60
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.9 60
    sudo update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 60
    sudo update-alternatives --set cc /usr/bin/gcc
    sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 60
    sudo update-alternatives --set c++ /usr/bin/g++
elif [ "$OPT" == "gcc5" ]; then
    sudo add-apt-repository -y ppa:dns/gnu
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    sudo apt-get update -q
    sudo apt-get install -y --allow-unauthenticated gcc-5 g++-5
    
    # sudo apt-get install gdebi
    #wget -nv http://ci.openframeworks.cc/gcc5/gcc5debs.tar.bz2
    #tar xjf gcc5debs.tar.bz2
    #rm gcc5debs.tar.bz2
    #sudo dpkg -i --force-depends cpp-5_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends gcc-5_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends gcc-5-base_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends g++-5_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends libstdc++-5-pic_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends libstdc++-5-dev_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends gcc-5-multilib_5.4.1-2ubuntu1~14.04_amd64.deb
    #sudo dpkg -i --force-depends g++-5-multilib_5.4.1-2ubuntu1~14.04_amd64.deb
    #rm *.deb
	
    sudo apt-get install -f
    sudo apt-get install -y gperf coreutils libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
    sudo apt-get remove -y --purge g++-4.8
    sudo apt-get autoremove
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
    g++ -v
elif [ "$OPT" == "gcc6" ]; then
    
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
    sudo apt-get update

    sudo add-apt-repository -y "deb http://cz.archive.ubuntu.com/ubuntu bionic main universe"
    sudo apt-get update
    
    sudo apt-get install -y --allow-unauthenticated gcc-6 g++-6
    sudo apt-get install -y gperf coreutils libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
    
    #sudo apt-get remove -y --purge g++-4.8

    sudo apt-get autoremove
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 100
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 100
    
    sudo add-apt-repository -r "deb http://cz.archive.ubuntu.com/ubuntu bionic main universe"

    g++ -v
else
	echo "GCC version not specified on OPT env var, set one of gcc4, gcc5 or gcc6"
fi

sudo apt-get install -y ccache
