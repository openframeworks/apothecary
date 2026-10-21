#!/usr/bin/env bash
# ANGLE ships two dynamic libraries/frameworks, rather than one static archive.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
TYPE=${TYPE:?TYPE is required}
SOURCE=${OUTPUT_FOLDER:-$ROOT/out}/angle
DEST=${ANGLE_STAGE_DIR:-$ROOT/xout/angle}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
case "$TYPE" in
    osx|macos) groups=('mac MAC MAC_ARM64'); output=macos ;;
    ios) groups=('device OS64' 'simulator SIMULATOR64 SIMULATORARM64'); output=ios ;;
    tvos) groups=('device TVOS' 'simulator SIMULATOR_TVOS SIMULATORARM64_TVOS'); output=tvos ;;
    catos) groups=('catalyst MAC_CATALYST MAC_CATALYST_ARM64'); output=catos ;;
    xros) groups=('device VISIONOS' 'simulator SIMULATOR64_VISIONOS SIMULATOR_VISIONOS'); output=xros ;;
    *) echo "Unsupported ANGLE Apple target: $TYPE" >&2; exit 1 ;;
esac
mkdir -p "$DEST/lib/$output"
for dir in include license; do
    test -d "$SOURCE/$dir"
    rm -rf "$DEST/$dir"
    cp -R "$SOURCE/$dir" "$DEST/$dir"
done
# Keep the original per-architecture provenance as well as final binary records.
while IFS= read -r -d '' record; do
    relative=${record#"$SOURCE/"}
    mkdir -p "$DEST/metadata/$(dirname "$relative")"
    cp "$record" "$DEST/metadata/$relative"
done < <(find "$SOURCE" -type f -name '*.pkl' -print0)
for component in libEGL libGLESv2; do
    flags=()
    for entry in "${groups[@]}"; do
        read -r -a platforms <<< "$entry"
        group=${platforms[0]}
        inputs=()
        framework=''
        for platform in "${platforms[@]:1}"; do
            candidate="$SOURCE/lib/$TYPE/$platform/$component.framework"
            if [ -f "$candidate/$component" ]; then
                inputs+=("$candidate/$component")
                framework=$candidate
            elif [ -f "$SOURCE/bin/$TYPE/$platform/$component.dylib" ]; then
                inputs+=("$SOURCE/bin/$TYPE/$platform/$component.dylib")
            fi
        done
        [ "${#inputs[@]}" -gt 0 ] || { echo "ANGLE $component missing $TYPE/$group" >&2; exit 1; }
        mkdir -p "$WORK/$component/$group"
        merged="$WORK/$component/$group/$component.dylib"
        if [ "${#inputs[@]}" -gt 1 ]; then
            xcrun lipo -create "${inputs[@]}" -output "$merged"
        else
            cp "${inputs[0]}" "$merged"
        fi
        if [ -n "$framework" ]; then
            staged="$WORK/$component/$group/$component.framework"
            cp -R "$framework" "$staged"
            cp "$merged" "$staged/$component"
            find "$staged" -type f -name '*.pkl' -delete
            flags+=(-framework "$staged")
        else
            flags+=(-library "$merged" -headers "$SOURCE/include")
        fi
    done
    xcframework="$DEST/lib/$output/$component.xcframework"
    rm -rf "$xcframework"
    xcodebuild -create-xcframework "${flags[@]}" -output "$xcframework"
    template=$(find "$SOURCE" -type f -name '*.pkl' -print | head -n 1)
    [ -n "$template" ] || { echo 'ANGLE source provenance missing' >&2; exit 1; }
    while IFS= read -r -d '' binary; do
        record="$(dirname "$binary")/angle.pkl"
        awk '!/^(binary|binarySha|architecture) =/' "$template" > "$record"
        printf 'binary = "%s"\nbinarySha = "%s"\narchitecture = "%s"\n' \
            "$(basename "$binary")" "$(shasum -a 256 "$binary" | cut -d ' ' -f 1)" \
            "$(xcrun lipo -archs "$binary")" >> "$record"
    done < <(find "$xcframework" -type f \( -name "$component" -o -name "$component.dylib" \) -print0)
done
