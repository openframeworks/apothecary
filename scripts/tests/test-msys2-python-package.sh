#!/usr/bin/env bash
# MSYS2 dropped mingw-w64-*-python3. pacboy python:p maps to
# mingw-w64-{x86_64,ucrt-x86_64,clang-x86_64,clang-aarch64}-python.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
workflow="$root/.github/workflows/build-msys2.yml"
install="$root/scripts/msys2/install_msys2.sh"

if grep -qE '(^|[[:space:]])python3:p([[:space:]]|$)' "$workflow"; then
    echo "FAIL: $workflow still requests pacboy python3:p (package was renamed to python)" >&2
    exit 1
fi
if ! grep -qE '(^|[[:space:]])python:p([[:space:]]|$)' "$workflow"; then
    echo "FAIL: $workflow must request pacboy python:p for mingw Python" >&2
    exit 1
fi
if grep -qE '(^|[[:space:]])python3([[:space:]]|$)' "$install"; then
    echo "FAIL: $install still requests pacboy python3 (package was renamed to python)" >&2
    exit 1
fi
if ! grep -qE '(^|[[:space:]])python([[:space:]]|$)' "$install"; then
    echo "FAIL: $install must request pacboy python for mingw Python" >&2
    exit 1
fi
echo "OK: msys2 mingw Python package is python / python:p"
