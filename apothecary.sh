#!/bin/bash
# pipe commands to core apothecary
APOTHE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APOTHE_DIR="$(realpath "$APOTHE_DIR/apothecary")"
APOTHE_SCRIPT="$(realpath "$APOTHE_DIR/apothecary")"
echo "$(date): [apothecary do my Command: $@]"
source "$APOTHE_SCRIPT" $@
EXIT_CODE=$?
echo "$EXIT_CODE"
exit ${EXIT_CODE}
