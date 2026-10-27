#!/usr/bin/env bash
# Exercise first-run setup ordering with a checkout that has no generated tools.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/angle/angle.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/.vendor/depot_tools/.git" "$fixture/scripts"
cd "$fixture"
# prepare() rewrites ANGLE's checked-in DEPS file before running gclient. Keep
# both a standalone GitHub mirror and an LLVM subtree entry in this fixture:
# the former verifies the rewrite and the latter ensures a second prepare()
# call remains valid after the standalone URL has already been rewritten.
cat > DEPS <<'EOF'
deps = [
  {'name': 'src/third_party/glslang', 'url': Var('chromium_git') + '/external/github.com/KhronosGroup/glslang@abc123'},
  {'name': 'src/third_party/llvm', 'url': Var('chromium_git') + '/external/github.com/llvm/llvm-project@def456'},
  {'name': 'src/third_party/libcxx', 'url': Var('chromium_git') + '/external/github.com/llvm/llvm-project/libcxx@789abc'},
]
EOF
echoError() { echo "$*" >&2; }
DOWNLOADER_SCRIPT="$fixture/downloader.sh"
printf 'ANGLE_TEST_DOWNLOADER_LOADED=1\n' > "$DOWNLOADER_SCRIPT"
export ANGLE_TEST_LOG="$fixture/commands"
verify_git_commit() { [ "$1" = "$fixture/.vendor/depot_tools" ]; [ "$2" = "$DEPOT_TOOLS_COMMIT" ]; }
printf 'printf "bootstrap\\n" >> "$ANGLE_TEST_LOG"\ntouch "$(dirname "$0")/python3_bin_reldir.txt"\n' > .vendor/depot_tools/ensure_bootstrap
python3() { [ -f .vendor/depot_tools/python3_bin_reldir.txt ]; printf 'config\n' >> "$ANGLE_TEST_LOG"; }
gclient() {
    [ -f .vendor/depot_tools/python3_bin_reldir.txt ]
    [ "$*" = 'sync --force --no-history --shallow' ]
    grep -Fq "'https://github.com/KhronosGroup/glslang@abc123'" DEPS
    grep -Fq "'https://github.com/llvm/llvm-project@def456'" DEPS
    grep -Fq "external/github.com/llvm/llvm-project/libcxx@789abc" DEPS
    printf 'sync\n' >> "$ANGLE_TEST_LOG"
}
TYPE=osx prepare
[ "$ANGLE_TEST_DOWNLOADER_LOADED" = 1 ]
printf 'bootstrap\nconfig\nsync\n' > expected
cmp expected "$ANGLE_TEST_LOG"
# Windows must bootstrap before gclient, then run GN/Ninja through cmd.exe.
: > "$ANGLE_TEST_LOG"
_angle_git_win_dir() { echo '/c/Program Files/Git/cmd'; }
cygpath() { printf '%s\n' "$2"; }
_angle_win_run() { printf '%s\n' "$*" >> "$ANGLE_TEST_LOG"; }
TYPE=vs prepare
head -1 "$ANGLE_TEST_LOG" | grep -F 'bootstrap/win_tools.bat'
sed -n '2p' "$ANGLE_TEST_LOG" | grep -F 'python scripts\bootstrap.py'
sed -n '3p' "$ANGLE_TEST_LOG" | grep -Fx 'gclient sync --force --no-history --shallow'
gn() { echo "Unexpected direct GN invocation" >&2; return 1; }
autoninja() { echo "Unexpected direct Ninja invocation" >&2; return 1; }
setup_vs_vars() { VS_INSTALL_PATH='C:\Program Files\Microsoft Visual Studio'; }
_angle_windows_sdk() { :; }
TYPE=vs ARCH=64 PLATFORM=x64 build
grep -F 'call gn.bat gen out/Release_x64' "$ANGLE_TEST_LOG" | grep -F 'target_os=\"win\"'
grep -F 'call autoninja.bat -C out/Release_x64 libEGL libGLESv2' "$ANGLE_TEST_LOG"
echo 'ANGLE bootstrap ordering and Windows command tests passed'
# Exercise the real launcher boundary: cmd.exe receives only a batch pathname,
# while quotes and Windows command syntax remain in the generated file.
source "$ROOT/apothecary/formulas/angle/angle.sh"
cmd.exe() {
    [ "$#" -eq 4 ] && [ "$1" = '//d' ] && [ "$2" = '//c' ] && [ "$3" = call ]
    [ -f "$4" ]
    cp "$4" "$fixture/launched.cmd"
    printf '%s\n' "$4" > "$fixture/launched-path"
    return "${ANGLE_TEST_EXIT:-0}"
}
_angle_win_run 'call "C:\path with spaces\bootstrap\win_tools.bat"'
tr -d '\r' < "$fixture/launched.cmd" > "$fixture/launched.txt"
grep -Fx 'call "C:\path with spaces\bootstrap\win_tools.bat"' "$fixture/launched.txt"
grep -E '^set "PATH=.*;%PATH%"$' "$fixture/launched.txt"
[ ! -e "$(cat "$fixture/launched-path")" ]
ANGLE_TEST_EXIT=17
if _angle_win_run 'call gclient.bat sync'; then
    echo 'Windows launcher swallowed command failure' >&2
    exit 1
else
    [ "$?" -eq 17 ]
fi
[ ! -e "$(cat "$fixture/launched-path")" ]
echo 'Windows batch transport, cleanup and exit propagation passed'

# tvOS must use Chromium's SDK discovery, including device/simulator metadata.
for tvos_platform in TVOS SIMULATOR_TVOS; do
    args=$(TYPE=tvos ARCH=arm64 PLATFORM="$tvos_platform" _angle_gn_args)
    [[ "$args" == *'target_platform="tvos"'* ]]
    [[ "$args" == *'use_blink=true'* ]]
    [[ "$args" != *ios_sdk_path* ]]
    if [ "$tvos_platform" = TVOS ]; then
        [[ "$args" == *'target_environment="device"'* ]]
    else
        [[ "$args" == *'target_environment="simulator"'* ]]
    fi
done
echo 'tvOS device and simulator use complete upstream SDK discovery'

ios_args=$(TYPE=ios ARCH=arm64 PLATFORM=OS64 _angle_gn_args)
[[ "$ios_args" == *'ios_deployment_target="15.0"'* ]]
[[ "$ios_args" != *'ios_deployment_target="13.0"'* ]]
osx_args=$(TYPE=osx ARCH=arm64 PLATFORM=MAC_ARM64 _angle_gn_args)
[[ "$osx_args" == *'mac_deployment_target="12.0"'* ]]
vs_args=$(TYPE=vs ARCH=64 PLATFORM=x64 _angle_gn_args)
[[ "$vs_args" == *'use_custom_libcxx=false'* ]]
[[ "$vs_args" == *'use_custom_libcxx_for_host=false'* ]]
[[ "$vs_args" == *'use_siso=false'* ]]
mkdir -p "$fixture/Xcode Toolchain/lib/darwin"
touch "$fixture/Xcode Toolchain/lib/darwin/libclang_rt.xros.a" "$fixture/Xcode Toolchain/lib/darwin/libclang_rt.xrossim.a"
xcrun() {
    [ "$#" -eq 4 ] && [ "$1" = --sdk ] && [ "$3" = clang ] && [ "$4" = --print-runtime-dir ] || return 1
    case "$2" in xros|xrsimulator) ;; *) return 1 ;; esac
    printf '%s\n' "$fixture/Xcode Toolchain/lib/darwin"
}
for xros_platform in XROS SIMULATOR_XROS; do
    xros_args=$(TYPE=xros ARCH=arm64 PLATFORM="$xros_platform" _angle_gn_args)
    [[ "$xros_args" == *'target_platform="xros"'* ]]
    [[ "$xros_args" == *'ios_deployment_target="2.0"'* ]]
    [[ "$xros_args" == *"angle_xros_clang_runtime_dir=\"$fixture/Xcode Toolchain/lib/darwin\""* ]]
    [[ "$xros_args" != *ios_sdk_path* ]]
    if [ "$xros_platform" = XROS ]; then
        [[ "$xros_args" == *'target_environment="device"'* ]]
    else
        [[ "$xros_args" == *'target_environment="simulator"'* ]]
    fi
done
echo 'iOS 15, macOS 12, MSVC libc++ and visionOS SDK discovery args passed'

# Match the actual labels passed by the Apple workflow and engine, rather than
# treating every simulator as ARCH=arm64. SIM_arm64 must not fall back to x64.
for target in ios tvos xros; do
    case "$target" in
        ios) simulator_platform=SIMULATORARM64 ;;
        tvos) simulator_platform=SIMULATORARM64_TVOS ;;
        xros) simulator_platform=SIMULATOR_VISIONOS ;;
    esac
    simulator_args=$(TYPE="$target" ARCH=SIM_arm64 PLATFORM="$simulator_platform" _angle_gn_args)
    [[ "$simulator_args" == *'target_cpu="arm64"'* ]]
    [[ "$simulator_args" == *'target_environment="simulator"'* ]]
    [[ "$simulator_args" != *'target_cpu="x64"'* ]]
done
intel_simulator_args=$(TYPE=ios ARCH=x86_64 PLATFORM=SIMULATOR64 _angle_gn_args)
[[ "$intel_simulator_args" == *'target_cpu="x64"'* ]]
echo 'Real ARM64 and Intel simulator labels select distinct GN CPUs'
mv "$fixture/Xcode Toolchain/lib/darwin/libclang_rt.xrossim.a" "$fixture/Xcode Toolchain/lib/darwin/saved.a"
if TYPE=xros ARCH=SIM_arm64 PLATFORM=SIMULATOR_VISIONOS _angle_gn_args; then
    echo 'Missing visionOS simulator runtime was incorrectly accepted' >&2
    exit 1
fi
mv "$fixture/Xcode Toolchain/lib/darwin/saved.a" "$fixture/Xcode Toolchain/lib/darwin/libclang_rt.xrossim.a"
unset -f xcrun

# visionOS ABI names introduced by the GN patch must pass Rust's allowlist.
mkdir -p build/config/apple build/config/clang build/rust
printf "'xrsimulator',\n" > build/config/apple/sdk_info.py
printf 'aarch64-apple-ios\n' > build/rust/known-target-triples.txt
cat > build/config/clang/BUILD.gn <<'EOF'
if (is_ios) {
  # For `target_environment` and `target_platform`.
  import("//build/config/apple/mobile_config.gni")
}

# Helper function for adding cflags to use a clang plugin.
# - `plugin` is the name of the plugin.
# - `plugin_arguments` is a list of arguments to pass to the plugin.
template("clang_lib") {
  if (true) {
    config(target_name) {
      _clang_lib_dir = "$clang_base_path/lib/clang/$clang_version/lib"
      _lib_file = "${_prefix}clang_rt.${_libname}${_suffix}.${_ext}"
      libs = [ "$_clang_lib_dir/$_dir/$_lib_file" ]
    }
  }
}

clang_lib("compiler_builtins") {
  if (is_mac) {
    libname = "osx"
  } else if (is_ios) {
    if (target_platform == "iphoneos") {
      if (target_environment == "simulator") {
        libname = "iossim"
      } else if (target_environment == "device") {
        libname = "ios"
      } else if (target_environment == "catalyst") {
        libname = "osx"
      } else {
        assert(false, "unsupported target_environment=$target_environment")
      }
    } else if (target_platform == "tvos") {
      if (target_environment == "simulator") {
        libname = "tvossim"
      } else if (target_environment == "device") {
        libname = "tvos"
      } else {
        assert(false, "unsupported target_environment=$target_environment")
      }
    } else {
      assert(false, "unsupported target_platform=$target_platform")
    }
  } else if (current_cpu != "ppc64" && current_cpu != "s390x") {
    libname = "builtins"
  }
}

EOF
TYPE=xros _angle_patch_xros_runtime
TYPE=xros _angle_patch_xros_runtime
TYPE=xros _angle_patch_platform_sources
TYPE=xros _angle_patch_platform_sources
for triple in aarch64-apple-visionos aarch64-apple-visionos-sim x86_64-apple-visionos; do
    grep -Fx "$triple" build/rust/known-target-triples.txt
done
[ "$(wc -l < build/rust/known-target-triples.txt | tr -d ' ')" = 4 ]
grep -F 'libname = "xros"' build/config/clang/BUILD.gn
grep -F 'libname = "xrossim"' build/config/clang/BUILD.gn
[ "$(grep -c 'target_platform == "xros"' build/config/clang/BUILD.gn)" -eq 2 ]
[ "$(grep -c 'angle_xros_clang_runtime_dir = ""' build/config/clang/BUILD.gn)" -eq 1 ]
grep -F '_clang_lib_dir = get_path_info(angle_xros_clang_runtime_dir, "dir")' build/config/clang/BUILD.gn
echo 'visionOS Rust and Clang runtime registration is complete and repeatable'

# The pinned bundle helper must accept both visionOS SDK names, even when
# code signing is disabled. Its mobile bundle layout is flat for these SDKs.
cat > build/config/apple/codesign.py <<'EOF'
class Bundle:
  @staticmethod
  def Kind(platform, extension):
    if platform in ('iphoneos', 'iphonesimulator'):
      return 'ios'
    if platform == 'macosx':
      if extension == '.framework':
        return 'mac_framework'
      return 'mac'
    if platform in ('watchos', 'watchsimulator'):
      return 'watchos'
    if platform in ('appletvos', 'appletvsimulator'):
      return 'tvos'
    raise ValueError('unknown bundle type %s for %s' % (extension, platform))
EOF
TYPE=xros _angle_patch_xros_bundle
TYPE=xros _angle_patch_xros_bundle
command python3 - <<'PY'
import runpy
bundle = runpy.run_path('build/config/apple/codesign.py')['Bundle']
for platform in ('xros', 'xrsimulator'):
    assert bundle.Kind(platform, '.framework') == 'xros'
for platform, kind in [('iphoneos', 'ios'), ('iphonesimulator', 'ios'),
                       ('watchos', 'watchos'), ('appletvos', 'tvos'),
                       ('macosx', 'mac_framework')]:
    assert bundle.Kind(platform, '.framework') == kind
try:
    bundle.Kind('unsupported', '.framework')
except ValueError:
    pass
else:
    raise AssertionError('Unknown platforms must still fail')
PY
echo 'visionOS bundle registration is repeatable and preserves existing platforms'

# Keep both Chromium SDK constants aligned with complete installed headers/libs.
source "$ROOT/apothecary/formulas/angle/angle.sh"
mkdir -p build/toolchain/win build/config/win "$fixture/sdk/Include/10.0.26100.0/um" "$fixture/sdk/Include/10.0.26100.0/ucrt" "$fixture/sdk/Lib/10.0.26100.0/um/x64" "$fixture/sdk/Lib/10.0.26100.0/ucrt/x64" "$fixture/sdk/Include/10.0.28000.0/um"
touch "$fixture/sdk/Include/10.0.26100.0/um/Windows.h" "$fixture/sdk/Include/10.0.26100.0/ucrt/stdio.h" "$fixture/sdk/Lib/10.0.26100.0/um/x64/kernel32.lib" "$fixture/sdk/Lib/10.0.26100.0/ucrt/x64/ucrt.lib"
printf "SDK_VERSION = '10.0.28000.0'\n" > build/vs_toolchain.py
cp build/vs_toolchain.py build/toolchain/win/setup_toolchain.py
printf 'config("compiler") {\n  cflags = [ "/utf-8", ]\n}\nconfig("winver") {\n  defines = ["NTDDI_VERSION=NTDDI_WIN11_BR", "_WIN32_WINNT=0x0A00", "WINVER=0x0A00"]\n}\n' > build/config/win/BUILD.gn
ANGLE_WINDOWS_SDK_ROOT="$fixture/sdk" _angle_windows_sdk
ANGLE_WINDOWS_SDK_ROOT="$fixture/sdk" _angle_windows_sdk
for sdk_file in build/vs_toolchain.py build/toolchain/win/setup_toolchain.py; do
    grep -Fx "SDK_VERSION = '10.0.26100.0'" "$sdk_file"
done
grep -F '"NTDDI_VERSION=0x0A000000", "_WIN32_WINNT=0x0A00", "WINVER=0x0A00"' build/config/win/BUILD.gn
grep -F 'cflags = [ "/utf-8", "/Zc:preprocessor", ]' build/config/win/BUILD.gn
[ "$(grep -c '/Zc:preprocessor' build/config/win/BUILD.gn)" -eq 1 ]
echoError() { echo "$*" >&2; }
if ANGLE_WINDOWS_SDK_ROOT="$fixture/sdk" WINDOWS_SDK_VERSION=10.0.28000.0 _angle_windows_sdk; then
    echo 'Incomplete SDK was incorrectly accepted' >&2
    exit 1
fi
echo 'Installed SDK selection, script alignment and incomplete-SDK rejection passed'
