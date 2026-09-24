#!/usr/bin/env bash
# Build and package FORMULAS_MODULAR_OPTIONAL for latest-modular.
# Not part of core bundle FORMULAS. Intended for push to bleeding/master.
set -euo pipefail

ROOT=$(
    cd "$(dirname "$0")"
    pwd -P
)/..
cd "$ROOT"

if [ -z "${TARGET:-}" ]; then
    echo "TARGET is not set"
    exit 1
fi

export TYPE="${TYPE:-$TARGET}"
export OUTPUT_FOLDER="${OUTPUT_FOLDER:-$ROOT/out}"
export ALWAYS_BUILD="${ALWAYS_BUILD:-1}"
export NO_COLOR="${NO_COLOR:-1}"
export UI_ANIM="${UI_ANIM:-0}"

# shellcheck source=calculate_formulas.sh
source "$ROOT/scripts/calculate_formulas.sh"

if [ -n "${PACKAGE_LIBS:-}" ]; then
    IFS=', ' read -r -a OPTIONAL <<< "$PACKAGE_LIBS"
else
    OPTIONAL=("${FORMULAS_MODULAR_OPTIONAL[@]:-}")
fi

if [ "${#OPTIONAL[@]}" -eq 0 ] || [ -z "${OPTIONAL[0]:-}" ]; then
    echo "No optional modular libraries for TARGET=$TARGET"
    exit 0
fi

if [ -n "${OPTIONAL_ARCHS:-}" ]; then
    # shellcheck disable=SC2206
    ARCHS=(${OPTIONAL_ARCHS})
else
    ARCHS=("${ARCH:-64}")
fi

echo "Optional modular libraries: [${OPTIONAL[*]}]"
echo "Archs: [${ARCHS[*]}]"

for lib in "${OPTIONAL[@]}"; do
    for arch in "${ARCHS[@]}"; do
        echo "==== apo update $lib TYPE=$TYPE ARCH=$arch ===="
        TYPE="$TYPE" ARCH="$arch" OUTPUT_FOLDER="$OUTPUT_FOLDER" \
            "$ROOT/apo" update "$lib"
    done
    if [[ "$TYPE" =~ ^(osx|macos|ios|tvos|xros|catos|watchos)$ ]]; then
        echo "==== apo modular $lib ===="
        TYPE="$TYPE" ARCH="${ARCHS[0]}" OUTPUT_FOLDER="$OUTPUT_FOLDER" \
            "$ROOT/apo" modular "$lib"
    fi
done

export PACKAGE_LIBS="${OPTIONAL[*]}"
"$ROOT/scripts/package-individual.sh"
