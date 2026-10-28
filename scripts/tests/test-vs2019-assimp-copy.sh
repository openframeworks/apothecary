#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/secure.sh" <<'EOF'
secure() {
    # Fail at the metadata boundary if the recipe passes a path it never copied.
    test -s "$1" || { echo "Missing metadata input: $1" >&2; exit 1; }
    printf '%s\n' "$1" >> "$ASSIMP_SECURE_LOG"
}
EOF
for version in 142 143 145; do
    for static in 1 0; do
        (
            source "$root/apothecary/formulas/assimp.sh"
            export TYPE=vs PLATFORM=x64 VC_VERSION="$version" ASSIMP_STATIC="$static" VERSION="$VER"
            export SECURE_SCRIPT="$fixture/secure.sh" ASSIMP_SECURE_LOG="$fixture/secure-$version-$static"
            source_dir="$fixture/source-$version-$static"
            destination="$fixture/package-$version-$static"
            mkdir -p "$source_dir/include/assimp" \
                "$source_dir/build_vs_x64_release/include/assimp" \
                "$source_dir/build_vs_x64_release/lib/Release" \
                "$source_dir/build_vs_x64_release/bin/Release" \
                "$source_dir/build_vs_x64_debug/lib/Debug" \
                "$source_dir/build_vs_x64_debug/bin/Debug"
            cd "$source_dir"
            printf 'public header\n' > include/assimp/base.h
            printf 'generated header\n' > build_vs_x64_release/include/assimp/config.h
            printf 'license\n' > LICENSE
            printf 'Release vc%s\n' "$version" > "build_vs_x64_release/lib/Release/assimp-vc${version}-mt.lib"
            printf 'Debug vc%s\n' "$version" > "build_vs_x64_debug/lib/Debug/assimp-vc${version}-mtd.lib"
            printf 'Release DLL vc%s\n' "$version" > "build_vs_x64_release/bin/Release/assimp-vc${version}-mt.dll"
            printf 'Debug DLL vc%s\n' "$version" > "build_vs_x64_debug/bin/Debug/assimp-vc${version}-mtd.dll"
            copy "$destination" > "$fixture/copy-$version-$static.log"
            cmp "build_vs_x64_release/lib/Release/assimp-vc${version}-mt.lib" "$destination/lib/vs/x64/Release/libassimp.lib"
            cmp "build_vs_x64_debug/lib/Debug/assimp-vc${version}-mtd.lib" "$destination/lib/vs/x64/Debug/libassimpD.lib"
            grep -Fxq "$destination/lib/vs/x64/Release/libassimp.lib" "$ASSIMP_SECURE_LOG"
            grep -Fxq "$destination/lib/vs/x64/Debug/libassimpD.lib" "$ASSIMP_SECURE_LOG"
            if [ "$static" = 0 ]; then
                cmp "build_vs_x64_release/bin/Release/assimp-vc${version}-mt.dll" "$destination/lib/vs/x64/Release/assimp-vc${version}-mt.dll"
                cmp "build_vs_x64_debug/bin/Debug/assimp-vc${version}-mtd.dll" "$destination/lib/vs/x64/Debug/assimp-vc${version}-mtd.dll"
            fi
        )
    done
done
echo 'Real Assimp copy function preserves static/DLL Debug/Release bytes for vc142, vc143 and vc145'
