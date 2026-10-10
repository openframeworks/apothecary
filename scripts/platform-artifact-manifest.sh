#!/usr/bin/env bash
# Per-formula fingerprints for raw, complete platform output (including private deps).
set -eo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
source scripts/calculate_formulas.sh >/dev/null
context_file=$(mktemp)
trap 'rm -f "$context_file"' EXIT
{
    printf 'platform-artifacts-v1\n'
    bash scripts/cache-toolchain.sh
    env | LC_ALL=C sort | sed -En '/^(BUNDLE|SDK|NDK|ANDROID_API|MSYSTEM|MINGW_PREFIX|.*DEPLOYMENT_TARGET|CPP_STANDARD|C_STANDARD|CFLAGS|CXXFLAGS|CPPFLAGS|LDFLAGS|FLAGS_.*|FLAG_.*|PTHREADS_ENABLED|MULTITHREADED_TYPE|VS_VER|OPENCV_.*)=/p'
    if [[ $TARGET == android ]]; then
        ndk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}/ndk/${NDK:?NDK is required}"
        test -f "$ndk_root/source.properties"
        cat "$ndk_root/source.properties"
        "$ndk_root/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" --version
    elif [[ $TARGET == msys2 ]]; then
        # The rolling MSYS2 installation must not reuse output from older headers/tools.
        pacman -Q | LC_ALL=C sort
    elif [[ $(uname -s) == Darwin ]]; then
        brew list --versions | LC_ALL=C sort
    fi
} > "$context_file"
export PLATFORM_ARTIFACT_CONTEXT="$context_file"
for formula in "${FORMULAS[@]}"; do
    key=$(bash scripts/modular-cache-key.sh "$formula")
    printf '%s\t%s\n' "$formula" "${key#key=}"
done
