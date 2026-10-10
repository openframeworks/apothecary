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
        clang --version
    fi
    vswhere='/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe'
    if [[ -x $vswhere ]]; then "$vswhere" -latest -property installationVersion; fi
fi
