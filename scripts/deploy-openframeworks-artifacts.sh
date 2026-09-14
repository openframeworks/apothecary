#!/usr/bin/env bash
set -euo pipefail

OF_ROOT="${1:?usage: $0 OPENFRAMEWORKS_ROOT ARTIFACT_DIRECTORY PLATFORM}"
ARTIFACT_DIRECTORY="${2:?usage: $0 OPENFRAMEWORKS_ROOT ARTIFACT_DIRECTORY PLATFORM}"
PLATFORM="${3:?usage: $0 OPENFRAMEWORKS_ROOT ARTIFACT_DIRECTORY PLATFORM}"

[[ -d "$OF_ROOT/libs" && -d "$OF_ROOT/addons" ]] || {
    echo "not an openFrameworks checkout: $OF_ROOT" >&2
    exit 1
}
[[ -d "$ARTIFACT_DIRECTORY" ]] || {
    echo "artifact directory does not exist: $ARTIFACT_DIRECTORY" >&2
    exit 1
}
[[ "$PLATFORM" == "osx" ]] || {
    echo "unsupported artifact platform: $PLATFORM" >&2
    exit 2
}

STAGING_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/of-libraries.XXXXXX")"
trap 'rm -rf "$STAGING_DIRECTORY"' EXIT

archive_count=0
while IFS= read -r archive; do
    archive_count=$((archive_count + 1))
    echo "Extracting $(basename "$archive")"
    tar -xjf "$archive" -C "$STAGING_DIRECTORY"
done < <(find "$ARTIFACT_DIRECTORY" -type f -name '*.tar.bz2' -print | sort)

[[ "$archive_count" -gt 0 ]] || {
    echo "no .tar.bz2 library artifacts found in $ARTIFACT_DIRECTORY" >&2
    exit 1
}

destination_for() {
    case "$1" in
        assimp) echo "$OF_ROOT/addons/ofxAssimpModelLoader/libs" ;;
        opencv|ippicv) echo "$OF_ROOT/addons/ofxOpenCv/libs" ;;
        libusb) echo "$OF_ROOT/addons/ofxKinect/libs" ;;
        libxml2|svgtiny) echo "$OF_ROOT/addons/ofxSvg/libs" ;;
        poco) echo "$OF_ROOT/addons/ofxPoco/libs" ;;
        *) echo "$OF_ROOT/libs" ;;
    esac
}

library_count=0
while IFS= read -r library; do
    name="$(basename "$library")"
    destination="$(destination_for "$name")"
    mkdir -p "$destination"
    rm -rf "$destination/$name"
    mv "$library" "$destination/$name"
    library_count=$((library_count + 1))
    echo "Installed $name"
done < <(find "$STAGING_DIRECTORY" -mindepth 1 -maxdepth 1 -type d -print | sort)

[[ "$library_count" -gt 0 ]] || {
    echo "artifacts did not contain any library directories" >&2
    exit 1
}

for framework in openssl libssl libcrypto; do
    [[ -d "$OF_ROOT/libs/openssl/lib/macos/$framework.xcframework" ]] || {
        echo "deployed artifacts are missing $framework.xcframework at libs/openssl/lib/macos" >&2
        exit 1
    }
done

echo "Installed $library_count libraries from $archive_count artifacts into openFrameworks"
