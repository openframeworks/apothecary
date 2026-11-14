#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
echoError() { printf '%s\n' "$*" >&2; }
echoWarning() { printf '%s\n' "$*"; }
# shellcheck disable=SC1091
source "$ROOT/apothecary/formulas/cef/cef.sh"

expect_platform() {
    local type="$1" arch="$2" want="$3" got
    TYPE=$type ARCH=$arch got="$(_cef_platform)"
    [ "$got" = "$want" ] || {
        echo "platform $type/$arch: got $got want $want" >&2
        exit 1
    }
}

expect_platform osx arm64 macosarm64
expect_platform osx x86_64 macosx64
expect_platform macos arm64 macosarm64
expect_platform linux 64 linux64
expect_platform linux x86_64 linux64
expect_platform linux arm64 linuxarm64
expect_platform linux aarch64 linuxarm64
expect_platform vs 64 windows64
expect_platform vs arm64 windowsarm64

if TYPE=vs ARCH=arm64ec _cef_platform 2>/dev/null; then
    echo 'vs/arm64ec should be rejected' >&2
    exit 1
fi
if TYPE=ios ARCH=arm64 _cef_platform 2>/dev/null; then
    echo 'ios should be rejected' >&2
    exit 1
fi
if TYPE=android ARCH=arm64 _cef_platform 2>/dev/null; then
    echo 'android should be rejected' >&2
    exit 1
fi
if TYPE=emscripten ARCH=64 _cef_platform 2>/dev/null; then
    echo 'emscripten should be rejected' >&2
    exit 1
fi
if TYPE=msys2 ARCH=64 _cef_platform 2>/dev/null; then
    echo 'msys2 should be rejected' >&2
    exit 1
fi

[ "$(_cef_sha256 linux64)" = "$SHA256_LINUX64" ]
[ "$(_cef_sha256 linuxarm64)" = "$SHA256_LINUXARM64" ]
[ "$(_cef_sha256 macosarm64)" = "$SHA256_MACOSARM64" ]
[ "$(_cef_sha256 macosx64)" = "$SHA256_MACOSX64" ]
[ "$(_cef_sha256 windows64)" = "$SHA256_WINDOWS64" ]
[ "$(_cef_sha256 windowsarm64)" = "$SHA256_WINDOWSARM64" ]

url="$(_cef_url macosarm64)"
[[ "$url" == *'%2B'* ]]
[[ "$url" != *'+'* ]]
[[ "$url" == https://cef-builds.spotifycdn.com/cef_binary_*_macosarm64.tar.bz2 ]]

[ "$(_cef_project_arch macosarm64)" = arm64 ]
[ "$(_cef_project_arch linux64)" = x86_64 ]
[ "$(_cef_project_arch windowsarm64)" = arm64 ]

_cef_is_sample cefclient
_cef_is_sample cefclient.exe
_cef_is_sample cefsimple
if _cef_is_sample libcef.so; then
    echo 'libcef.so is runtime, not a sample' >&2
    exit 1
fi
if _cef_is_sample chrome-sandbox; then
    echo 'chrome-sandbox is runtime, not a sample' >&2
    exit 1
fi

cmake_txt="$(_cef_write_wrapper_cmake)"
[[ "$cmake_txt" == *'add_subdirectory(${CEF_LIBCEF_DLL_WRAPPER_PATH} libcef_dll_wrapper)'* ]]
[[ "$cmake_txt" != *'add_subdirectory(tests/'* ]]

for required in osx linux vs; do
    case " ${FORMULA_TYPES[*]} " in
        *" $required "*) ;;
        *)
            echo "FORMULA_TYPES missing $required: ${FORMULA_TYPES[*]}" >&2
            exit 1
            ;;
    esac
done
for extra in ios android emscripten msys2; do
    case " ${FORMULA_TYPES[*]} " in
        *" $extra "*)
            echo "FORMULA_TYPES should stay desktop-only: ${FORMULA_TYPES[*]}" >&2
            exit 1
            ;;
    esac
done

echo 'CEF platform, hash and URL mapping tests passed'
