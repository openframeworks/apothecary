#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$root/scripts/vs/toolset.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export VS_BASE_PATH="$fixture/Visual Studio"
mkdir -p "$VS_BASE_PATH/VC/Tools/MSVC/14.29.30133/bin/Hostx64/x64" \
    "$VS_BASE_PATH/VC/Tools/MSVC/14.44.35207/bin/Hostx64/x64"
export VS_TOOLSET=v142 VS_HOSTPLATFORM=Hostx64 BUILD_PLATFORM=x64
export ARCH=64 VS_COMPILER=MSVC VS_VER_GEN='17 2022' CPP_STANDARD=max CMAKE_WIN_SDK='-DCMAKE_SYSTEM_VERSION=10.0.20348.0'
apothecary_vs_configure_toolset
[[ $VS_VER_DIR == 14.29.30133 && $VS_BIN_PATH == *14.29.30133/bin/Hostx64/x64 ]]
[[ $PATH == "$VS_BIN_PATH:"* && $CPP_STANDARD == 23 && $CPP_STANDARD_MODE == latest ]]
[[ $CC == cl && $CXX == cl ]]
[[ $CMAKE_GENERATOR == 'Visual Studio 17 2022' && $CMAKE_GENERATOR_TOOLSET == 'v142,version=14.29.30133,host=x64' ]]
[[ $CMAKE_WIN_SDK == *'-T v142,version=14.29.30133,host=x64' ]]
# Explicit older standards remain usable. No fallback to the newest compiler.
( CPP_STANDARD=20; apothecary_vs_configure_toolset; [[ $CPP_STANDARD == 20 && -z ${CPP_STANDARD_MODE:-} ]] )
if ( VS_TOOLS_VERSION=14.28; apothecary_vs_configure_toolset ); then exit 1; fi
if ( ARCH=arm64ec; apothecary_vs_configure_toolset ); then exit 1; fi
if ( VS_TOOLSET=v143; apothecary_vs_configure_toolset ); then exit 1; fi
if ( VS_BASE_PATH="$fixture/missing"; apothecary_vs_configure_toolset ); then exit 1; fi
# A normal invocation is unaffected by the opt-in selector.
( unset VS_TOOLSET; CPP_STANDARD=23; apothecary_vs_configure_toolset; [[ $CPP_STANDARD == 23 ]] )
# Exercise the real engine's VS initialization with both toolsets installed.
python3 - "$root/apothecary/apothecary" "$fixture/vs-init.sh" <<'PY'
import pathlib, sys
source = pathlib.Path(sys.argv[1]).read_text()
start = source.index('# used when building for vs')
end = source.index('####  Platform Determination for Targets', start)
pathlib.Path(sys.argv[2]).write_text(source[start:end])
PY
(
    set +u # The engine predates nounset; the helper itself is tested with it.
    echoVerbose() { :; }
    echoError() { echo "$*" >&2; }
    cygpath() { printf '%s\n' "${@: -1}"; }
    export APOTHECARY_DIR="$root/apothecary" TYPE=vs VS_VER=17 DRIVE="$fixture"
    export CPP_STANDARD=max
    unset VS_BIN_PATH VS_VER_DIR
    WIN10_INSTALLED_SDK_2022=10.0.20348.0
    WIN10_INSTALLED_SDK_2022_HEX=0x0A004F5C
    TARGET_WIN_11=0 VS_HOST=amd64
    source "$fixture/vs-init.sh"
    [[ $VS_VER == 17 && $VS_VER_GEN == '17 2022' && $VS_VER_DIR == 14.29.30133 ]]
    [[ $CPP_STANDARD == 23 && $CPP_STANDARD_MODE == latest && $PATH == "$VS_BIN_PATH:"* ]]
)
echo 'VS toolset selection tests passed'
