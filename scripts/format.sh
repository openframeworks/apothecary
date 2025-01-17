#!/bin/bash
# set -x
echo " Format Bash Scripts all nice"
printHelp() {
    echo "Help"
    cat <<EOF
    Usage:
    ."$SCRIPT_DIR/format.sh"
    format_scripts [DIRECTORY]
    Example: format_scripts ./src
    This script fixes format of sh if you have shfmt installed
EOF
}

format_scripts() {
    local directory="$1"

    if [ -z "$1" ]; then
        printHelp
    fi

    # Check if shfmt is installed
    # if ! command -v shfmt &>/dev/null; then
    #     echo "shfmt is not installed. Please install shfmt to automatically format shell scripts."
    #     # Uncomment the next line to abort if shfmt is not installed
    #     return 1
    # fi

    if ! command -v dos2unix &>/dev/null; then
        echo "dos2unix is not installed. Please install shfmt to automatically format shell scripts."
        # Uncomment the next line to abort if shfmt is not installed
        return 1
    fi

    # Check if the directory exists
    if [ ! -d "$directory" ]; then
        echo "The specified directory does not exist: [$directory]"
        return 1
    fi

    echo "Formatting shell scripts in [$directory]... listing all with 755"
    find "$directory" -type f -name "*.sh" ! -perm 755 -exec ls -l {} \;
    echo "Listing shell scripts in [$directory] without +x ..."
    find "$directory" -type f -name "*.sh" ! -perm /a+x -exec ls -l {} \;

    sh_files=$(find "$directory" -type f -name "*.sh")
    if [ -z "$sh_files" ]; then
        echo "No .sh files found in [$directory.]"
        return 0
    fi

    echo "Found the following .sh files:"
    echo "$sh_files"

    # Iterate over the list of files
    for file in $sh_files; do
        echo " Processing: [$file]"
        if [ "$file" == "/format.sh" ]; then
            continue
        fi

        # temp_file=$(mktemp)

        shfmt -i 4 -ci -w "$file"

        # Safely expand tabs and format the script
        # expand -t 4 "$file" | shfmt -i 4 -ci -w - > "$temp_file"

        # # Replace the original file only if the operation was successful
        # if [ $? -eq 0 ]; then
        #     mv "$temp_file" "$file"
        # else
        #     echo "An error occurred. Original file remains unchanged."
        #     rm -f "$temp_file"
        # fi

        # Format TAB to spaces
        # expand -t 4 "$file" | shfmt -i 4 -ci -w - > "$file"

        # Format Spaces to TAB
        # unexpand -t 4 "$file" | shfmt -i 4 -ci -w - > "$file"

        # Fix line endings with dos2unix
        dos2unix "$file" && echo "Converted to Unix line endings: [$file]"

        # Set permissions to 755
        chmod +x "$file" && echo "Set permissions to +x: [$file]"
    done

    # Stage the formatted .sh files with git add
    # Note: This will stage all .sh files in the directory, not just the ones modified by shfmt
    git add "$(realpath "$directory")"/*.sh

    echo "Shell scripts formatted and staged successfully."
}

format_scripts $1
