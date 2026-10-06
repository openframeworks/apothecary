#!/usr/bin/env bash
set -euo pipefail
SOURCE_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/scripts" "$TEST_ROOT/apothecary/formulas/example" "$TEST_ROOT/bin"
cp "$SOURCE_ROOT/scripts/modular-cache-key.sh" "$SOURCE_ROOT/scripts/build-modular-optional.sh" "$TEST_ROOT/scripts/"
cat > "$TEST_ROOT/apothecary/formulas/example/example.sh" <<'FORMULA'
FORMULA_DEPENDS=("dependency")
VER=1.0
SOURCE_COMMIT=0123456789012345678901234567890123456789
FORMULA
printf 'FORMULA_DEPENDS=()\nVER=1.0\n' > "$TEST_ROOT/apothecary/formulas/dependency.sh"
printf 'FORMULA_DEPENDS=()\nVER=1.0\n' > "$TEST_ROOT/apothecary/formulas/unrelated.sh"
printf 'FORMULAS_MODULAR_OPTIONAL=(example)\n' > "$TEST_ROOT/scripts/calculate_formulas.sh"
cat > "$TEST_ROOT/apo" <<'APO'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$TEST_ROOT/calls"
mkdir -p "$OUTPUT_FOLDER/example" "$TEST_ROOT/xout/example"
printf compiled > "$OUTPUT_FOLDER/example/library.a"
APO
cat > "$TEST_ROOT/scripts/package-individual.sh" <<'PACKAGE'
#!/usr/bin/env bash
printf packaged >> "$TEST_ROOT/packages"
PACKAGE
chmod +x "$TEST_ROOT/apo" "$TEST_ROOT/scripts/package-individual.sh"
# Stable tool reports make key assertions independent of host installations.
for tool in cmake ninja clang xcodebuild; do
    printf '#!/bin/sh\necho mock-tool-1\n' > "$TEST_ROOT/bin/$tool"
    chmod +x "$TEST_ROOT/bin/$tool"
done
cat > "$TEST_ROOT/bin/xcrun" <<'TOOL'
#!/bin/sh
echo mock-clang-sdk-1
TOOL
chmod +x "$TEST_ROOT/bin/xcrun"
export TEST_ROOT TARGET=osx TYPE=osx OPTIONAL_ARCHS='x86_64 arm64'
export PATH="$TEST_ROOT/bin:$PATH" OUTPUT_FOLDER="$TEST_ROOT/out"
mkdir -p "$TEST_ROOT/scripts/tvOS"
printf 'installer-v1\n' > "$TEST_ROOT/scripts/tvOS/install.sh"
printf 'helper-v1\n' > "$TEST_ROOT/scripts/apple-install-tools.sh"
git -C "$TEST_ROOT" init -q
git -C "$TEST_ROOT" add .
key() { bash "$TEST_ROOT/scripts/modular-cache-key.sh" example; }
# tvOS is a mixed-case tracked directory even on a case-sensitive runner.
tvos_base=$(TARGET=tvos key)
printf changed >> "$TEST_ROOT/scripts/tvOS/install.sh"
[[ $(TARGET=tvos key) != "$tvos_base" ]]
sed -i.bak '$d' "$TEST_ROOT/scripts/tvOS/install.sh"
[[ $(TARGET=tvos key) == "$tvos_base" ]]
base=$(key)
printf changed >> "$TEST_ROOT/scripts/apple-install-tools.sh"
[[ $(key) != "$base" ]]
sed -i.bak '$d' "$TEST_ROOT/scripts/apple-install-tools.sh"
[[ $(key) == "$base" ]]
printf changed >> "$TEST_ROOT/apothecary/formulas/unrelated.sh"
[[ $(key) == "$base" ]]
printf changed >> "$TEST_ROOT/apothecary/formulas/dependency.sh"
[[ $(key) != "$base" ]]
sed -i.bak '$d' "$TEST_ROOT/apothecary/formulas/dependency.sh"
[[ $(key) == "$base" ]]
printf changed >> "$TEST_ROOT/apothecary/formulas/example/example.sh"
[[ $(key) != "$base" ]]
sed -i.bak '$d' "$TEST_ROOT/apothecary/formulas/example/example.sh"
[[ $(OPTIONAL_ARCHS=arm64 key) != "$base" ]]
[[ $(TARGET=ios key) != "$base" ]]
[[ $(CFLAGS=-O3 key) != "$base" ]]
printf '#!/bin/sh\necho mock-tool-2\n' > "$TEST_ROOT/bin/cmake"
[[ $(key) != "$base" ]]
bash "$TEST_ROOT/scripts/build-modular-optional.sh"
[[ $(wc -l < "$TEST_ROOT/calls" | tr -d ' ') == 3 ]]
MODULAR_CACHE_HIT=true bash "$TEST_ROOT/scripts/build-modular-optional.sh"
[[ $(wc -l < "$TEST_ROOT/calls" | tr -d ' ') == 3 ]]
[[ $(cat "$TEST_ROOT/packages") == packagedpackaged ]]
# An incomplete exact cache must fail instead of publishing incomplete output.
rm -rf "$TEST_ROOT/xout/example"
if MODULAR_CACHE_HIT=true bash "$TEST_ROOT/scripts/build-modular-optional.sh"; then
    echo 'FAIL: incomplete cache accepted' >&2; exit 1
fi
echo 'Modular cache invalidation and reuse tests passed'
