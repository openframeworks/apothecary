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

winget install -e --id Microsoft.WindowsTerminal
winget install Ninja-build.Ninja
winget install jqlang.jq
