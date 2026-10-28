#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/secure.sh" <<'EOF'
secure() {
    test -s "$1" || { echo "Missing metadata input: $1" >&2; return 1; }
    printf '%s\n' "$1" >> "$OPENCV_SECURE_LOG"
}
EOF
for layout in vc16 vc17 vc18 flat; do
    (
        source "$root/apothecary/formulas/opencv/opencv.sh"
        export TYPE=vs PLATFORM=x64 BUILD_PLATFORM=x64 VS_VER=17 VERSION="$VER"
        export SECURE_SCRIPT="$fixture/secure.sh" OPENCV_SECURE_LOG="$fixture/secure-$layout"
        source_dir="$fixture/source-$layout"
        destination="$fixture/package-$layout"
        mkdir -p "$source_dir"
        cd "$source_dir"
        printf 'license\n' > LICENSE
        for configuration in Release Debug; do
            prefix="build_vs_x64/$configuration"
            if [ "$layout" = flat ]; then
                libdir="$prefix/staticlib"
            else
                libdir="$prefix/x64/$layout/staticlib"
            fi
            mkdir -p "$libdir" "build_vs_x64/3rdparty/lib/$configuration"
            suffix=""
            [ "$configuration" != Debug ] || suffix=d
            printf '%s world\n' "$configuration" > "$libdir/opencv_world${FILE_VERSION}${suffix}.lib"
            printf '%s module\n' "$configuration" > "$libdir/opencv_img_hash${FILE_VERSION}${suffix}.lib"
            printf '%s third party\n' "$configuration" > "build_vs_x64/3rdparty/lib/$configuration/ittnotify.lib"
        done
        mkdir -p build_vs_x64/Release/include/opencv2 build_vs_x64/Release/etc
        printf 'header\n' > build_vs_x64/Release/include/opencv2/core.hpp
        printf 'data\n' > build_vs_x64/Release/etc/config.xml
        copy "$destination" > "$fixture/copy-$layout.log"
        for configuration in Release Debug; do
            prefix="build_vs_x64/$configuration"
            if [ "$layout" = flat ]; then libdir="$prefix/staticlib"; else libdir="$prefix/x64/$layout/staticlib"; fi
            suffix=""
            [ "$configuration" != Debug ] || suffix=d
            for name in opencv_world opencv_img_hash; do
                cmp "$libdir/${name}${FILE_VERSION}${suffix}.lib" "$destination/lib/vs/x64/$configuration/${name}${FILE_VERSION}${suffix}.lib"
            done
            cmp "build_vs_x64/3rdparty/lib/$configuration/ittnotify.lib" "$destination/lib/vs/x64/$configuration/ittnotify.lib"
            grep -Fxq "$destination/lib/vs/x64/$configuration/opencv_world${FILE_VERSION}${suffix}.lib" "$OPENCV_SECURE_LOG"
        done
    )
done
echo 'Real OpenCV copy preserves Debug/Release modules, third-party libraries and metadata for vc16/vc17/vc18/flat installs'
