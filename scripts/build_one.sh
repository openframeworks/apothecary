#!/usr/bin/env bash

echo Build $formula_name

echoDots(){
    sleep 0.1 # Waiting for a brief period first, allowing jobs returning immediatly to finish
    while isRunning $1; do
        for i in $(seq 1 10); do
            echo -ne .
            if ! isRunning $1; then
                printf "\r"
                return;
            fi
            sleep 1
        done
        printf "\r                    "
        printf "\r"
    done
}

ARGS="-f -j$PARALLEL -p -t$TARGET -d$OUTPUT_FOLDER "
if [ "$ARCH" != "" ] ; then
    ARGS="$ARGS -a$ARCH"
fi

if [ "$VERBOSE" = true ] ; then
    echo "./apothecary $ARGS update $formula_name"
    cd scripts/apothecary
    ./apothecary $ARGS update $formula_name
else
    echo "./apothecary $ARGS update $formula_name" > formula.log 2>&1
    cd scripts/apothecary
    ./apothecary $ARGS update $formula_name >> formula.log 2>&1 &

    apothecaryPID=$!
    echoDots $apothecaryPID
    wait $apothecaryPID

    echo "Tail of log for $formula_name"
    tail -n 100 formula.log
fi