#!/bin/bash
# pipe commands to core apothecary
APOTHE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

APOTHE_DIR="$(realpath "$APOTHE_DIR")"
SECURE_SCRIPT="$(realpath "$APOTHE_DIR/../scripts/secure.sh")"
APOTHE_SCRIPT="$(realpath "$APOTHE_DIR/apothecary")"
log_command() {
    local command="$1"
    local source="${BASH_SOURCE[1]}"
    echo "$(date): [Command: ${command}]" >> "${LOG_FILE}"
}
log_command "$@"
source "$APOTHE_SCRIPT" $@
EXIT_CODE=$?
echo "$EXIT_CODE"
exit ${EXIT_CODE}
