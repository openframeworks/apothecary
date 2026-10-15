#!/usr/bin/env bash
# Report the actual build toolchain once per platform artifact job.
set -euo pipefail
cmake --version
if command -v ninja >/dev/null; then ninja --version; else echo 'ninja=unavailable'; fi
if [[ $(uname -s) == Darwin ]]; then
    xcodebuild -version
    xcrun clang --version
    xcodebuild -showsdks
else
    if [[ ${TARGET:-} == msys2 ]]; then
        if command -v cc >/dev/null; then cc --version; else clang --version; fi
    else
        if command -v clang >/dev/null; then clang --version; elif command -v gcc >/dev/null; then gcc --version; else echo 'host-clang=unavailable'; fi
    fi
    vswhere='/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe'
    if [[ -x $vswhere ]]; then "$vswhere" -latest -property installationVersion; fi
fi

# Capture the selected compiler and Windows SDK/MSVC versions, not just host clang.
if [[ ${TARGET:-} == linux ]]; then
    for tool in "${CC:-}" "${CXX:-}"; do
        tool="${tool%% *}"
        if [[ -n $tool ]] && command -v "$tool" >/dev/null 2>&1; then "$tool" --version; fi
    done
fi
if [[ ${TARGET:-} == vs ]]; then
    for version in /c/Program\ Files/Microsoft\ Visual\ Studio/*/*/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt; do
        if [[ -f $version ]]; then printf '%s: ' "$version"; cat "$version"; fi
    done
    for sdk in /c/Program\ Files\ \(x86\)/Windows\ Kits/10/Include/*; do
        if [[ -d $sdk ]]; then printf 'windows-sdk=%s\n' "${sdk##*/}"; fi
    done
fi
