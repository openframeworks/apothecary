#!/usr/bin/env bash
# `apo * all` must walk real formulas only, not patches sitting in formulas/.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ENGINE="$ROOT/apothecary/apothecary"

extract=$(mktemp)
trap 'rm -rf "$extract" "$fixture"' EXIT
awk '/^function listAllFormulas\(/,/^}$/' "$ENGINE" > "$extract"
grep -q 'function listAllFormulas' "$extract"

fixture=$(mktemp -d)
FORMULAS_DIR="$fixture/formulas"
DEPENDS_SUBDIR=_depends
mkdir -p "$FORMULAS_DIR/curl" "$FORMULAS_DIR/$DEPENDS_SUBDIR" "$FORMULAS_DIR/opencv"
touch "$FORMULAS_DIR/assimp.sh"
touch "$FORMULAS_DIR/nghttp2.sh"
touch "$FORMULAS_DIR/nghttp2-lib-only.patch"
touch "$FORMULAS_DIR/notes.md"
touch "$FORMULAS_DIR/curl/curl.sh"
touch "$FORMULAS_DIR/opencv/opencv.sh"
touch "$FORMULAS_DIR/$DEPENDS_SUBDIR/pkg-config.sh"
# Directory without a matching script is not a formula.
mkdir -p "$FORMULAS_DIR/cmake-only"
touch "$FORMULAS_DIR/cmake-only/CMakeLists.txt"

# shellcheck source=/dev/null
source "$extract"
got=$(listAllFormulas | sort)
want=$(printf '%s\n' assimp curl nghttp2 opencv)
[ "$got" = "$want" ]

real_names=$(FORMULAS_DIR="$ROOT/apothecary/formulas" DEPENDS_SUBDIR=_depends listAllFormulas)
echo "$real_names" | grep -qx nghttp2
echo "$real_names" | grep -qx curl
if echo "$real_names" | grep -qx nghttp2-lib-only; then
    echo "nghttp2-lib-only.patch must not be treated as a formula" >&2
    exit 1
fi
if echo "$real_names" | grep -qx _depends; then
    echo "_depends must not be treated as a formula" >&2
    exit 1
fi

grep -F 'cleanFormula|remove|remove-lib|remove-all' "$ENGINE" >/dev/null

echo 'listAllFormulas skips patches and _depends'
