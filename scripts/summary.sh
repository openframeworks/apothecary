#!/bin/bash

ORIGINAL_DIR="$(pwd)"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $CURRENT_DIR
APOTHECARY_LEVEL="$(cd "$CURRENT_DIR/.." && pwd)"

if [ -d "$APOTHECARY_LEVEL/out" ]; then
    echo "out dir exists"
else
    echo "OUT_DIR does not exist. Creating it..."
    mkdir -p "$APOTHECARY_LEVEL/out"
fi

OUT_DIR="$(cd "$APOTHECARY_LEVEL/out" && pwd)"
cd $OUT_DIR


SUMMARY_FILE="manifesto.md"

# Initialize the summary file with a table header
echo "# Manifesto for All Libraries" > "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Library | Version | Build Time | Build Number | Git URL | C++ Standard | C Standard | Linker Flags | Dependencies | Binary | Binary SHA | SHA Type | Source SHA | Defines | Frameworks |" >> "$SUMMARY_FILE"
echo "|---------|---------|------------|--------------|---------|--------------|------------|--------------|-------------|--------|------------|----------|------------|---------|-----------|" >> "$SUMMARY_FILE"

# Find all .pkl files and process them
find "$OUT_DIR" -type f -name "*.pkl" | while read -r pkl_file; do
  # Extract library name and information
  LIB_NAME=$(basename "$(dirname "$pkl_file")")
  LIB_INFO=$(parse_pkl "$pkl_file")

  # Extracting individual values safely
  version=$(echo "$LIB_INFO" | grep "Version" | cut -d '|' -f3 | xargs)
  build_time=$(echo "$LIB_INFO" | grep "Build Time" | cut -d '|' -f3 | xargs)
  build_number=$(echo "$LIB_INFO" | grep "Build Number" | cut -d '|' -f3 | xargs)
  git_url=$(echo "$LIB_INFO" | grep "Git URL" | cut -d '|' -f3 | xargs)
  cpp_standard=$(echo "$LIB_INFO" | grep "C++ Standard" | cut -d '|' -f3 | xargs)
  c_standard=$(echo "$LIB_INFO" | grep "C Standard" | cut -d '|' -f3 | xargs)
  linker_flags=$(echo "$LIB_INFO" | grep "Linker Flags" | cut -d '|' -f3 | xargs)
  dependencies=$(echo "$LIB_INFO" | grep "Dependencies" | cut -d '|' -f3 | xargs)
  binary=$(echo "$LIB_INFO" | grep "Binary" | cut -d '|' -f3 | xargs)
  binary_sha=$(echo "$LIB_INFO" | grep "Binary SHA" | cut -d '|' -f3 | xargs)
  sha_type=$(echo "$LIB_INFO" | grep "SHA Type" | cut -d '|' -f3 | xargs)
  source_sha=$(echo "$LIB_INFO" | grep "Source SHA" | cut -d '|' -f3 | xargs)
  defines=$(echo "$LIB_INFO" | grep "Defines" | cut -d '|' -f3 | xargs)
  frameworks=$(echo "$LIB_INFO" | grep "Frameworks" | cut -d '|' -f3 | xargs)

  # Append row to the table
  echo "| $LIB_NAME | $version | $build_time | $build_number | $git_url | $cpp_standard | $c_standard | $linker_flags | $dependencies | $binary | $binary_sha | $sha_type | $source_sha | $defines | $frameworks |" >> "$SUMMARY_FILE"
done

# Post the summary to GitHub Actions
if [ "${GITHUB_ACTIONS}" == "true" ]; then
    echo "## Build Summary" >> "$GITHUB_STEP_SUMMARY"
    cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
else
    echo "Not running in GitHub Actions. Skipping summary update."
fi

cd "$ORIGINAL_DIR"
