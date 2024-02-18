#!/bin/bash
set -e
set -o pipefail
# trap any script errors and exit
trap "trapError" ERR

trapError() {
	echo
	echo " ^ Received error ^"
	cat formula.log
	exit 1
}

installPackages(){
    sudo apt-get update -q
    sudo apt-get -y install multistrap unzip coreutils gperf
    sudo apt-get update && sudo apt-get install -y autoconf libtool automake
}

createRaspbianImg(){
    #needed since Ubuntu 18.04 - allow non https repositories
    mkdir -p raspbian/etc/apt/apt.conf.d/
    echo 'Acquire::AllowInsecureRepositories "true";' | sudo tee raspbian/etc/apt/apt.conf.d/90insecure
    multistrap -a arm64 -d raspbian -f multistrap.conf
}

downloadToolchain(){
    wget https://github.com/openframeworks/openFrameworks/releases/download/tools/cross-gcc-10.3.0-pi_64.tar.gz
    tar xvf cross-gcc-10.3.0-pi_64.tar.gz
    mv cross-pi-gcc-10.3.0-64 rpi_toolchain
    rm cross-gcc-10.3.0-pi_64.tar.gz

    if [ "$(ls -A ~/rpi2_toolchain)" ]; then
        echo "Using cached RPI2 toolchain"
    else
        sudo apt-get install -y crossbuild-essential-arm64
        wget -q http://ci.openframeworks.cc/rpi2_toolchain.tar.bz2 # aarch64?????
        tar xjf rpi2_toolchain.tar.bz2 -C ~/
        rm rpi2_toolchain.tar.bz2
    fi
}

downloadFirmware(){
    echo "no firmware"
    # wget -nv https://github.com/raspberrypi/firmware/archive/master.zip -O firmware.zip
    # unzip firmware.zip
    # cp -r firmware-master/opt raspbian/
    # rm -r firmware-master
    # rm firmware.zip
}

relativeSoftLinks(){
    for link in $(ls -la | grep "\-> /" | sed "s/.* \([^ ]*\) \-> \/\(.*\)/\1->\/\2/g"); do
        lib=$(echo $link | sed "s/\(.*\)\->\(.*\)/\1/g");
        link=$(echo $link | sed "s/\(.*\)\->\(.*\)/\2/g");
        rm $lib
        ln -s ../../..$link $lib
    done

    for f in *; do
        error=$(grep " \/lib/" $f > /dev/null 2>&1; echo $?)
        if [ $error -eq 0 ]; then
            sed -i "s/ \/lib/ ..\/..\/..\/lib/g" $f
            sed -i "s/ \/usr/ ..\/..\/..\/usr/g" $f

}

createArchImg(){
    #sudo apt-get install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf libasound2-dev

    #sudo apt-get -y update
    #sudo apt-get -f -y --force-yes dist-upgrade
    #sudo apt-get install -y libgssapi-krb5-2 libkrb5-3 libidn11
    #sudo ./arch-bootstrap.sh archlinux
    sudo add-apt-repository ppa:dns/gnu -y
    sudo apt-get update -q
    sudo apt-get install -y coreutils realpath gperf
	cd $HOME
	wget -v http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz 
	mkdir archlinux
	

    #./arch-bootstrap_downloadonly.sh -a armv7h -r "http://eu.mirror.archlinuxarm.org/" archlinux
	junest -- <<EOF
        tar xzf ~/ArchLinuxARM-rpi-aarch64-latest.tar.gz -C ~/archlinux/ 2> /dev/null
        sed -i s_/etc/pacman_$HOME/archlinux/etc/pacman_g ~/archlinux/etc/pacman.conf
		pacman --noconfirm -r ~/archlinux/ --config ~/archlinux/etc/pacman.conf --arch=aarch64 -Syu
		pacman --noconfirm -r ~/archlinux/ --config ~/archlinux/etc/pacman.conf --arch=aarch64 -S make pkg-config gcc raspberrypi-firmware
EOF
	touch $HOME/archlinux/timestamp
}

installJunest(){
	git clone git://github.com/fsquillace/junest ~/.local/share/junest
	export PATH=~/.local/share/junest/bin:$PATH
    junest setup
    junest -- << EOF
        echo updating keys
        sudo pacman -S gnupg --noconfirm
        sudo pacman-key --populate archlinux
        sudo pacman-key --refresh-keys
        echo updating packages
		sudo pacman -Syyu --noconfirm
		sudo pacman -S --noconfirm git flex grep gcc pkg-config make wget sed
EOF
}

if [[ $(uname -m) != armv* ]]; then

	ROOT=$( cd "$(dirname "$0")" ; pwd -P )
	echo $ROOT
	cd $ROOT

	installPackages
	createRaspbianImg
	downloadToolchain
	downloadFirmware

        cp -rn rpi_toolchain/aarch64-linux-gnu/libc/lib/* $ROOT/raspbian/usr/lib/
        cp -rn rpi_toolchain/aarch64-linux-gnu/libc/usr/lib/* $ROOT/raspbian/usr/lib/
        cp -rn rpi_toolchain/aarch64-linux-gnu/lib/* $ROOT/raspbian/usr/lib/

        cd $ROOT/raspbian/usr/lib
        relativeSoftLinks
        cd $ROOT/raspbian/usr/lib/aarch64-linux-gnu
        relativeSoftLinks
	installJunest
	createArchImg
	downloadToolchain
	downloadFirmware

	cd $HOME/archlinux/usr/lib
	relativeSoftLinks "../.." "..\/.."
	#cd $ROOT/archlinux/usr/lib/arm-unknown-linux-gnueabihf
	#relativeSoftLinks  "../../.." "..\/..\/.."
	#cd $ROOT/raspbian/usr/lib/gcc/arm-unknown-linux-gnueabihf/5.3
	#relativeSoftLinks  "../../../.." "..\/..\/..\/.."
	
fi
