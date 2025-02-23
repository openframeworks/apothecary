#!/usr/bin/env bash
set -e

# trap any script errors and exit
trap "trapError" ERR

trapError() {
    echo
    echo " ^ Received error ^"
    exit 1
}

isRunning() {
    if [ “$(uname)” == “Linux” ]; then
        if [ -d /proc/$1 ]; then
            return 0
        else
            return 1
        fi
    else
        number=$(ps aux | sed -E "s/[^ ]* +([^ ]*).*/\1/g" | grep ^$1$ | wc -l)

        if [ $number -gt 0 ]; then
            return 0
        else
            return 1
        fi
    fi
}

echoDots() {
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return
            fi
            sleep 2
        done
        printf "\r                    "
        printf "\r"
    done
}

if command -v winget >/dev/null 2>&1; then
    winget install -e --id Microsoft.WindowsTerminal
    winget install Ninja-build.Ninja
    winget install jqlang.jq
    winget install --id Oracle.JDK.17 -e
    winget install Python.Python.3
fi

if [ "${GITHUB_ACTIONS:-0}" = 0 ]; then

    if command -v python >/dev/null 2>&1; then
        python -m ensurepip --upgrade
        echo "python is installed. Proceeding to install numpy..."
        python -m pip install numpy
    elif command -v python3 >/dev/null 2>&1; then
        python3 -m pip --version 2>/dev/null
        echo "python3 is installed. Proceeding to install numpy..."
        python3 -m pip install numpy
    else
        echo "python is not installed. Skipping numpy installation."
    fi

fi
