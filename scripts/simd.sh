#!/bin/bash

# this is to search for instrinct code that may not be availble in arm devices and needs checking 
# pass a variable to this for another location 

# Default directory to search
DEFAULT_SEARCH_DIR="../apothecary/apothecary/build"

# use the first command-line argument is the search directory, or use the default
SEARCH_DIR="${1:-$DEFAULT_SEARCH_DIR}"

# file to save the results (optional)
LOG_FILE=""

# headers associated with SIMD / Instrintics 
SIMD_HEADERS=("xmmintrin.h" "emmintrin.h" "immintrin.h" "arm_neon.h" "arm64_neon.h")

# Function to search for SIMD headers
search_simd() {
    for header in "${SIMD_HEADERS[@]}"; do
        echo "Searching for $header in $SEARCH_DIR"
        if [ -n "$LOG_FILE" ]; then
            grep -rnw "$SEARCH_DIR" -e "#include.*$header" >> "$LOG_FILE"
        else
            grep -rnw "$SEARCH_DIR" -e "#include.*$header"
        fi
    done
    echo "Finished"
}

# Check for logging option
if [ "$2" == "--log" ]; then
    LOG_FILE="simd_search_results.txt"
    echo "Logging results to $LOG_FILE"
    # Clear the log file
    > "$LOG_FILE"
fi

# Call the search function
search_simd
