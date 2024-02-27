#!/bin/bash

printHelp(){
cat << EOF
    Usage:
    ."$SCRIPT_DIR/format.sh"
    format_scripts [DIRECTORY]
    Example: format_scripts ./src
    This script fixes format of sh if you have shfmt installed
EOF
}

format_scripts() {
    local directory="$1"

    if [ -z "$1" ]
    then printHelp; fi

    # Check if shfmt is installed
    if ! command -v shfmt &>/dev/null; then
        echo "shfmt is not installed. Please install shfmt to automatically format shell scripts."
        # Uncomment the next line to abort if shfmt is not installed
        # exit 1
        return 1
    fi

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "The specified directory does not exist: $directory"
        return 1
    fi

    echo "Formatting shell scripts in $directory..."

    # Find and format all .sh files recursively within the directory
    find "$directory" -type f -name "*.sh" -exec shfmt -i 4 -ci -w {} \;

    # Stage the formatted .sh files with git add
    # Note: This will stage all .sh files in the directory, not just the ones modified by shfmt
    git add "$(realpath "$directory")"/*.sh

    echo "Shell scripts formatted and staged successfully."
}
