#!/usr/bin/env bash
# Human-readable evidence attached to the final release state. Never dump env.
set -eo pipefail
printf 'runner-image=%s\nrunner-os=%s\nrunner-arch=%s\n' "${ImageVersion:-unknown}" "${RUNNER_OS:-unknown}" "${RUNNER_ARCH:-unknown}"
bash scripts/cache-toolchain.sh
for tool in gcc g++ clang clang++ emcc meson ninja; do
    if command -v "$tool" >/dev/null 2>&1; then "$tool" --version || printf '%s version unavailable\n' "$tool"; fi
done
if [ -n "${NDK:-}" ]; then
    ndk_root="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}/ndk/$NDK"
    cat "$ndk_root/source.properties"
fi
if command -v dpkg-query >/dev/null 2>&1; then dpkg-query -W; fi
if command -v pacman >/dev/null 2>&1; then pacman -Q; fi
for key in SDK NDK ANDROID_API EMSDK_VERSION VS_VER VS_STUDIO C_STANDARD CPP_STANDARD CFLAGS CXXFLAGS LDFLAGS; do
    printf '%s=%s\n' "$key" "${!key:-unspecified}"
done
if [ -f "${EMSDK:-$HOME/emsdk}/emsdk_env.sh" ]; then
    source "${EMSDK:-$HOME/emsdk}/emsdk_env.sh" >/dev/null 2>&1
    emcc --version
fi
