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

SUMMARY_FILE="Manifesto.md"

# Initialize Manifesto file with a Markdown table
echo "# Manifesto for All Libraries" > "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Library | Version | Build Time | Build Number | Git URL | C++ Standard | C Standard | Linker Flags | Dependencies | Binary | Binary SHA | SHA Type | Source SHA | Defines | Frameworks |" >> "$SUMMARY_FILE"
echo "|---------|---------|------------|--------------|---------|--------------|------------|--------------|-------------|--------|------------|----------|------------|---------|-----------|" >> "$SUMMARY_FILE"

# Function to safely extract values (removes quotes & spaces)
extract_value() {
    local key="$1"
    awk -F' *= *' -v key="$key" '$1 == key {gsub(/"/, "", $2); print $2}' "$pkl_file" | tr -d '\n'
}

# Process all .pkl files
find "$OUT_DIR" -type f -name "*.pkl" | while read -r pkl_file; do
  LIB_NAME=$(basename "$(dirname "$pkl_file")")

  echo "Processing $LIB_NAME ($pkl_file)..."

  # Extract values correctly
  name=$(extract_value "name")
  version=$(extract_value "version")
  build_time=$(extract_value "buildTime")
  build_number=$(extract_value "buildNumber")
  git_url=$(extract_value "gitUrl")
  cpp_standard=$(extract_value "cppStandard")
  c_standard=$(extract_value "cStandard")
  linker_flags=$(extract_value "linkerFlags")
  dependencies=$(extract_value "dependencies")
  binary=$(extract_value "binary")
  binary_sha=$(extract_value "binarySha")
  sha_type=$(extract_value "shaType")
  source_sha=$(extract_value "sourceSHA")
  defines=$(extract_value "defines")
  frameworks=$(extract_value "frameworks")

  # Ensure empty values are replaced with `-`
  version=${version:-"-"}
  build_time=${build_time:-"-"}
  build_number=${build_number:-"-"}
  git_url=${git_url:-"-"}
  cpp_standard=${cpp_standard:-"-"}
  c_standard=${c_standard:-"-"}
  linker_flags=${linker_flags:-"-"}
  dependencies=${dependencies:-"-"}
  binary=${binary:-"-"}
  binary_sha=${binary_sha:-"-"}
  sha_type=${sha_type:-"-"}
  source_sha=${source_sha:-"-"}
  defines=${defines:-"-"}
  frameworks=${frameworks:-"-"}

  # **Fix Binary & SHA merging by wrapping each properly**
  binary="\`$binary\`"
  binary_sha="\`$binary_sha\`"

  # Append properly formatted row
  echo "| $name | $version | $build_time | $build_number | $git_url | $cpp_standard | $c_standard | $linker_flags | $dependencies | $binary | $binary_sha | $sha_type | $source_sha | $defines | $frameworks |" >> "$SUMMARY_FILE"
done

# Post summary to GitHub Actions
if [ "${GITHUB_ACTIONS}" == "true" ]; then
    echo "## Build Summary" >> "$GITHUB_STEP_SUMMARY"
    cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
else
    echo "Not running in GitHub Actions. Skipping summary update."
fi

cd "$ORIGINAL_DIR"
