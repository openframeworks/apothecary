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

if [ ! -z ${OPT+x} ]; then
    if [ "$OPT" == "gcc5" ]; then
        sudo add-apt-repository -y ppa:dns/gnu
        sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
        sudo apt-get update -q
        sudo apt-get install gdebi
        wget http://ci.openframeworks.cc/gcc5/gcc5debs.tar.bz2
        tar xjf gcc5debs.tar.bz2
        rm gcc5debs.tar.bz2
        sudo gdebi -n cpp-5_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n g++-5_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n gcc-5-base_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n libstdc++-5-pic_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n libstdc++-5-dev_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n gcc-5_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n gcc-5-multilib_5.4.1-2ubuntu1~14.04_amd64.deb
        sudo gdebi -n g++-5-multilib_5.4.1-2ubuntu1~14.04_amd64.deb
        rm *.deb

        sudo apt-get install -y gperf coreutils realpath libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
        sudo apt-get remove -y --purge g++-4.8
        sudo apt-get autoremove
        sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 100
        sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 100
        g++ -v
    else
        sudo add-apt-repository -y ppa:dns/gnu
        sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
        sudo apt-get update -q
        sudo apt-get install gdebi
        wget http://ci.openframeworks.cc/gcc5/gcc6debs.tar.bz2
        tar xjf gcc6debs.tar.bz2
        rm gcc6debs.tar.bz2
        sudo gdebi -n cpp-6_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n g++-6_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n gcc-6-base_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n libstdc++-6-pic_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n libstdc++-6-dev_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n gcc-6_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n gcc-6-multilib_6.2.0-3ubuntu11~14.04_amd64.deb
        sudo gdebi -n g++-6-multilib_6.2.0-3ubuntu11~14.04_amd64.deb
        rm *.deb

        sudo apt-get install -y gperf coreutils realpath libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
        sudo apt-get remove -y --purge g++-4.8
        sudo apt-get autoremove
        sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 100
        sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 100
        g++ -v
    fi
else
    sudo add-apt-repository -y ppa:dns/gnu
    sudo apt-get update -q
    sudo apt-get install -y gperf coreutils realpath libxrandr-dev libxinerama-dev libx11-dev libxcursor-dev libxi-dev
fi
