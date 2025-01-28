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

# Function to parse a single .pkl file
parse_pkl_python() {
    if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Please install it to use parse_pkl."
        exit 1
    fi
    local pkl_file="$1"
  python3 - <<EOF
import os

def parse_apple_pkl(file_path):
    data = {}
    with open(file_path, "r") as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                key, value = map(str.strip, line.split("=", 1))
                key = key.strip("\"")
                value = value.strip(";").strip("\"")
                data[key] = value
    return data

try:
    # Parse the Apple-style PKL file
    parsed_data = parse_apple_pkl("${pkl_file}")

    # Extract required fields
    name = parsed_data.get("name", "Unknown")
    version = parsed_data.get("version", "Unknown")
    build_time = parsed_data.get("buildTime", "Unknown")
    build_number = parsed_data.get("buildNumber", "Unknown")
    target_type = parsed_data.get("type", "Unknown")
    dependencies = parsed_data.get("dependencies", "None")
    binary_sha = parsed_data.get("binarySha", "Unknown")
    cpp_standard = parsed_data.get("cppStandard", "Unknown")
    linker_flags = parsed_data.get("linkerFlags", "None")

    # Custom header
    print(f"## {name} - {target_type}")
    print(f"Version: {version}")
    print(f"Build Time: {build_time}")
    print(f"Build Number: {build_number}")
    print(f"Dependencies: {dependencies}")
    print(f"C++ Standard: {cpp_standard}")
    print(f"Binary SHA: {binary_sha}")
    print(f"Linker Flags: {linker_flags}")
    print()
except Exception as e:
    print(f"Error reading ${pkl_file}: {e}")
EOF
}

parse_pkl() {
  local pkl_file="$1"

  # Ensure the file exists
  if [[ ! -f "$pkl_file" ]]; then
    echo "Error: File $pkl_file does not exist."
    return 1
  fi

  local name version build_time build_number target_type git_url cpp_standard c_standard linker_flags dependencies binary binary_sha sha_type source_sha defines frameworks

  # Read the file line by line
  while IFS= read -r line; do
    line=$(echo "$line" | tr -d '\r' | xargs) # Remove CR characters and trim whitespace
    if [[ "$line" == *=* ]]; then
      key=$(echo "$line" | cut -d= -f1 | xargs)
      value=$(echo "$line" | cut -d= -f2 | sed 's/[;""]//g' | xargs)
      case "$key" in
        "name") name="$value" ;;
        "version") version="$value" ;;
        "buildTime") build_time="$value" ;;
        "buildNumber") build_number="$value" ;;
        "type") target_type="$value" ;;
        "gitUrl") git_url="$value" ;;
        "cppStandard") cpp_standard="$value" ;;
        "cStandard") c_standard="$value" ;;
        "linkerFlags") linker_flags="$value" ;;
        "dependencies") dependencies="$value" ;;
        "binary") binary="$value" ;;
        "binarySha") binary_sha="$value" ;;
        "shaType") sha_type="$value" ;;
        "sourceSHA") source_sha="$value" ;;
        "defines") defines="$value" ;;
        "frameworks") frameworks="$value" ;;
      esac
    fi
  done < "$pkl_file"

  # Output as a Markdown table, skipping empty values
  echo "## ${name:-Unknown} - ${target_type:-Unknown}"
  echo
  echo "| Field         | Value |"
  echo "|---------------|-------|"
  [[ -n "$version" ]] && echo "| Version       | $version |"
  [[ -n "$build_time" ]] && echo "| Build Time    | $build_time |"
  [[ -n "$build_number" ]] && echo "| Build Number  | $build_number |"
  [[ -n "$git_url" ]] && echo "| Git URL       | $git_url |"
  [[ -n "$cpp_standard" ]] && echo "| C++ Standard  | $cpp_standard |"
  [[ -n "$c_standard" ]] && echo "| C Standard    | $c_standard |"
  [[ -n "$linker_flags" ]] && echo "| Linker Flags  | $linker_flags |"
  [[ -n "$dependencies" ]] && echo "| Dependencies  | $dependencies |"
  [[ -n "$binary" ]] && echo "| Binary        | $binary |"
  [[ -n "$binary_sha" ]] && echo "| Binary SHA    | $binary_sha |"
  [[ -n "$sha_type" ]] && echo "| SHA Type      | $sha_type |"
  [[ -n "$source_sha" ]] && echo "| Source SHA    | $source_sha |"
  [[ -n "$defines" ]] && echo "| Defines       | $defines |"
  [[ -n "$frameworks" ]] && echo "| Frameworks    | $frameworks |"
  echo
}

# Initialize the summary file
echo "# Manifeso for All Libraries" > "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Find all .pkl files and process them
find "$OUT_DIR" -type f -name "*.pkl" | while read -r pkl_file; do
  # Extract information from the .pkl file
  echo "Processing $pkl_file..."
  LIB_INFO=$(parse_pkl "$pkl_file")

  # Add library information to the summary file
  # echo "## $(basename "$(dirname "$pkl_file")")" >> "$SUMMARY_FILE"
  echo "$LIB_INFO" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
done

# Post the summary to GitHub Actions
if [ "${GITHUB_ACTIONS}" == "true" ]; then
    echo "## Build Summary" >> "$GITHUB_STEP_SUMMARY"
    cat "$SUMMARY_FILE" >> "$GITHUB_STEP_SUMMARY"
else
    echo "Not running in GitHub Actions. Skipping summary update."
fi

cd "$ORIGINAL_DIR"
