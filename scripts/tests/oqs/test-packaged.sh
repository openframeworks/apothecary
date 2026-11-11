#!/usr/bin/env bash
# Native archive/relocation test; not a release publisher or XCFramework build.
set -euo pipefail
root=${1:?Usage: test-packaged.sh OUTPUT_ROOT TYPE PLATFORM}
type=${2:?TYPE is required}
platform=${3:?PLATFORM is required}
root=$(cd "$root" && pwd -P)
tests=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
work=$(mktemp -d "${TMPDIR:-/tmp}/oqs-package-test.XXXXXX")
trap 'rm -rf "$work"' EXIT
packages="$work/relocated packages"
mkdir -p "$packages"
for formula in liboqs openssl zlib oqsprovider openssh; do
    [ -d "$root/$formula" ] || { echo "Missing staged formula: $formula" >&2; exit 1; }
    tar -czf "$work/$formula.tar.gz" -C "$root" "$formula"
    tar -xzf "$work/$formula.tar.gz" -C "$packages"
done
cmake -S "$tests" -B "$work/consumer" \
    -DDEPS_ROOT="$packages" -DTYPE="$type" -DPLATFORM="$platform"
cmake --build "$work/consumer" --parallel 4
ctest --test-dir "$work/consumer" --no-tests=error --output-on-failure
bash "$tests/test-openssh.sh" "$packages" "$type" "$platform"
