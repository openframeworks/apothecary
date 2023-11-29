#!/bin/bash
#set -e
#set -o pipefail
# trap any script errors and exit
trap "trapError" ERR

SUDO=

trapError() {
	echo
	echo " ^ Received error ^"
	exit 1
}

createArchImg(){
    #sudo apt-get install -y gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf libasound2-dev

    #sudo apt-get -y update
    #sudo apt-get -f -y --force-yes dist-upgrade
    #sudo apt-get install -y libgssapi-krb5-2 libkrb5-3 libidn11
    #sudo ./arch-bootstrap.sh archlinux
    sudo add-apt-repository ppa:dns/gnu -y
    sudo apt-get update -q
    sudo apt-get install -y coreutils gperf
    mkdir ~/archlinux
    cd ~/archlinux
	wget -v http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-armv7-latest.tar.gz
	
    #./arch-bootstrap_downloadonly.sh -a armv7h -r "http://eu.mirror.archlinuxarm.org/" archlinux
	junest -- <<EOF
        tar xzf ~/ArchLinuxARM-rpi-armv7-latest.tar.gz 2> /dev/null
        sed -i s_/etc/pacman_$HOME/archlinux/etc/pacman_g ~/archlinux/etc/pacman.conf
		pacman --noconfirm -r ~/archlinux/ --config ~/archlinux/etc/pacman.conf --arch=armv7h -Syu
		pacman --noconfirm -r ~/archlinux/ --config ~/archlinux/etc/pacman.conf --arch=armv7h -S make pkg-config gcc raspberrypi-firmware
EOF
	touch $HOME/archlinux/timestamp
}

downloadToolchain(){
    #wget http://archlinuxarm.org/builder/xtools/x-tools7h.tar.xz
    #tar xf x-tools7h.tar.xz
    #rm x-tools7h.tar.xz
    if [ "$(ls -A ~/rpi2_toolchain)" ]; then
        echo "Using cached RPI2 toolchain"
    else
        wget -q https://github.com/openframeworks/openFrameworks/releases/download/tools/rpi2_toolchain.tar.bz2
        tar xjf rpi2_toolchain.tar.bz2 -C ~/
        rm rpi2_toolchain.tar.bz2
    fi
}

downloadFirmware(){
    wget -q https://github.com/raspberrypi/firmware/archive/master.zip -O firmware.zip
    unzip -q firmware.zip
    ${SUDO} cp -r firmware-master/opt archlinux/
    rm -r firmware-master
    rm firmware.zip
}


relativeSoftLinks(){
    rel_link=$1
    escaped_rel_link=$2
    for link in $(ls -la | grep "\-> /" | sed "s/.* \([^ ]*\) \-> \/\(.*\)/\1->\/\2/g"); do
        lib=$(echo $link | sed "s/\(.*\)\->\(.*\)/\1/g");
        link=$(echo $link | sed "s/\(.*\)\->\(.*\)/\2/g");
        ${SUDO} rm $lib
        ${SUDO} ln -s ${rel_link}/${link} $lib
    done

    for f in *; do
        error_lib=$(grep " \/lib/" $f > /dev/null 2>&1; echo $?)
        error_usr=$(grep " \/usr/" $f > /dev/null 2>&1; echo $?)
        if [ $error_lib -eq 0 ] || [ $error_usr -eq 0 ]; then
            ${SUDO} sed -i "s/ \/lib/ $escaped_rel_link\/lib/g" $f
            ${SUDO} sed -i "s/ \/usr/ $escaped_rel_link\/usr/g" $f
        fi
    done
}

installJunest(){
	git clone https://github.com/fsquillace/junest ~/.local/share/junest
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
	installJunest
	createArchImg
	downloadToolchain
	downloadFirmware

	#cd $HOME/archlinux/usr/lib
	#relativeSoftLinks "../.." "..\/.."
	#cd $ROOT/archlinux/usr/lib/arm-unknown-linux-gnueabihf
	#relativeSoftLinks  "../../.." "..\/..\/.."
	#cd $ROOT/raspbian/usr/lib/gcc/arm-unknown-linux-gnueabihf/5.3
	#relativeSoftLinks  "../../../.." "..\/..\/..\/.."
	
fi
