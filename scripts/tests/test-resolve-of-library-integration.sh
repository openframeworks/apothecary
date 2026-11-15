#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/scripts/resolve-of-library-integration.sh"

resolve() {
    local out
    out="$(
        LIBRARY_REF="$1" WORKFLOW_REF_TYPE="$2" WORKFLOW_REF_NAME="$3" PLATFORM="$4" \
            bash "$script"
    )"
    printf '%s\n' "$out"
}

expect() {
    local got expected
    got="$(resolve "$1" "$2" "$3" "$4")"
    expected="$5"
    if [[ "$got" != "$expected" ]]; then
        echo "FAIL: LIBRARY_REF=$1 type=$2 name=$3 platform=$4" >&2
        echo " expected:" >&2
        echo "$expected" >&2
        echo " got:" >&2
        echo "$got" >&2
        exit 1
    fi
}

expect auto tag v12.2.0 linux $'library_ref=v12.2.0\nplatforms=["linux"]'
expect '' tag v12.2.0 linux $'library_ref=v12.2.0\nplatforms=["linux"]'
expect auto branch bleeding linux $'library_ref=bleeding\nplatforms=["linux"]'
expect '' branch bleeding macos $'library_ref=bleeding\nplatforms=["macos"]'
expect v12.2.0 branch bleeding linux $'library_ref=v12.2.0\nplatforms=["linux"]'
expect latest tag v12.2.0 windows $'library_ref=latest\nplatforms=["windows"]'
expect latest-modular branch master android $'library_ref=latest-modular\nplatforms=["android"]'
expect ' v12.2.0 ' tag ignored linux $'library_ref=v12.2.0\nplatforms=["linux"]'
expect auto tag v12.2.0 all $'library_ref=v12.2.0\nplatforms=["linux","macos","ios","tvos","android","emscripten","windows"]'

if LIBRARY_REF=auto WORKFLOW_REF_TYPE=tag WORKFLOW_REF_NAME=v12.2.0 PLATFORM=wasm bash "$script" >/dev/null 2>&1; then
    echo "FAIL: expected unsupported platform to fail" >&2
    exit 1
fi

workflow="$root/.github/workflows/test-openframeworks-libraries.yml"
grep -q 'default: auto' "$workflow" || { echo "FAIL: dispatch library_ref should default to auto" >&2; exit 1; }
grep -q 'type: string' "$workflow" || { echo "FAIL: dispatch library_ref should be a string" >&2; exit 1; }
grep -q -- '- all' "$workflow" || { echo "FAIL: platform choices should include all" >&2; exit 1; }
grep -q 'needs.plan.outputs.platforms' "$workflow" || { echo "FAIL: integration matrix should use plan platforms" >&2; exit 1; }
grep -q 'needs.plan.outputs.library_ref' "$workflow" || { echo "FAIL: integration should use resolved library_ref" >&2; exit 1; }
grep -q 'resolve-of-library-integration.sh' "$workflow" || { echo "FAIL: plan job should run the resolver" >&2; exit 1; }

echo "OK: OF library integration resolves tags and all platforms"
