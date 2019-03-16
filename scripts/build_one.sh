#!/usr/bin/env bash

echo Build $formula_name

ARGS="-f -j$PARALLEL -p -t$TARGET -d$OUTPUT_FOLDER "
if [ "$ARCH" != "" ] ; then
    ARGS="$ARGS -a$ARCH"
fi

if [ "$VERBOSE" = true ] ; then
    echo "./apothecary $ARGS update $formula_name"
    cd $APOTHECARY_PATH
    ./apothecary $ARGS update $formula_name
else
    echo "./apothecary $ARGS update $formula_name" > formula.log 2>&1
    cd $APOTHECARY_PATH
    ./apothecary $ARGS update $formula_name >> formula.log 2>&1 &

    apothecaryPID=$!
    echoDots $apothecaryPID
    wait $apothecaryPID

    echo "Tail of log for $formula_name"
    tail -n 100 formula.log
fi