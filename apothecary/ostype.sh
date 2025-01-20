# uses uname to get a more grained os type
# from http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

function lowercase() {
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

OS=$(lowercase $(uname))
DISTRO=""
DEVICE=""

if [ "$OS" == "darwin" ]; then
    OS="osx"
elif [ "$OS" == "windowsnt" ]; then
    OS="vs"
elif [ "${OS:0:5}" == "mingw" -o "$OS" == "msys_nt-6.3" ]; then
    OS="msys2"
elif [ "$OS" == "linux" ]; then
    ARCH=$(uname -m)
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu)
                export DISTRO="ubuntu"
                ;;
            raspbian)
                export DISTRO="raspios"
                ;;
            debian)
                if grep -q "Raspberry Pi" /proc/cpuinfo; then
                    export DISTRO="raspios"
                else
                    export DISTRO="debian"
                fi
                ;;
            *)
                export DISTRO="$ID"
                ;;
        esac
    fi
    if [[ "$DISTRO" == "raspios" ]]; then
        if [[ -f /proc/cpuinfo ]]; then
            REVISION=$(grep "^Revision" /proc/cpuinfo | awk '{print $3}')
            case "$REVISION" in
                    a02082|a22082|a32082|a52082)
                        export DEVICE="Raspberry Pi 3"
                        ;;
                    a03111|b03111|b03112|b03114)
                        export DEVICE="Raspberry Pi 4"
                        ;;
                    b03140|c03140|d03140|c03145)
                        export DEVICE="Raspberry Pi 5"
                        ;;
                    *)
                        export DEVICE="Unknown Raspberry Pi Model"
                        ;;
                esac
            echo "$DEVICE"
        else
            export DEVICE="Unknown (no /proc/cpuinfo)"
        fi
    else
        export DEVICE="Not a Raspberry Pi"
    fi
fi

echo "$OS ${DISTRO} ${DEVICE}"
