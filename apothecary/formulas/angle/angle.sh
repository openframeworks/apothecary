#!/usr/bin/env bash
#
# ANGLE — google/angle via GN (not MetalANGLE)
# https://github.com/google/angle
#
# VS:  GLES → D3D11. Apple: GLES → Metal (osx/ios/tvos/catos/xros).
# metalangle is the frozen MGLKit fork. glon12 is desktop GL → D3D12.
# Official build is depot_tools + gn + ninja (not the unofficial CMake).
# target_os must be "win" / "mac" / "ios" (PR #533 passed TYPE=vs and that is wrong).
#
# Output: libEGL + libGLESv2. DLL on VS, dylib on macOS, framework on
# ios/tvos/catos/xros (ANGLE's iOS shared target is an ios_framework_bundle).
# OF keeps ofGLProgrammableRenderer; the window must be EGL under OF_USE_ANGLE.

FORMULA_TYPES=("vs" "osx" "ios" "tvos" "catos" "xros")
FORMULA_DEPENDS=()

VER=2026.08.13
SOURCE_COMMIT=7e8009eb2c42996fe6e7337bf8d12e1cfe4a1b80
BUILD_ID=14
DEFINES="angle_enable_metal=true angle_enable_d3d11=true"

GIT_URL=https://github.com/google/angle.git
GIT_URL_FALLBACK=https://chromium.googlesource.com/angle/angle
DEPOT_TOOLS_URL=https://chromium.googlesource.com/chromium/tools/depot_tools.git
DEPOT_TOOLS_COMMIT=a03dfbf7f2d1cefa2795d81d59ca4f16c8616a8f

function download() {
    . "$DOWNLOADER_SCRIPT"

    if [ -d angle ]; then
        rm -rf angle
    fi
    mkdir -p angle
    git -C angle init
    git -C angle remote add origin "${GIT_URL}" 2>/dev/null || git -C angle remote set-url origin "${GIT_URL}"
    if ! git -C angle fetch --depth=1 origin "${SOURCE_COMMIT}"; then
        echoWarning "github.com/google/angle fetch failed; trying ${GIT_URL_FALLBACK}"
        git -C angle remote set-url origin "${GIT_URL_FALLBACK}"
        git -C angle fetch --depth=1 origin "${SOURCE_COMMIT}"
    fi
    git -C angle checkout --force FETCH_HEAD
    verify_git_commit angle "${SOURCE_COMMIT}"
}

# Git for Windows git.exe — Win32 gclient/vpython cannot run MSYS /usr/bin/git.
function _angle_git_win_dir() {
    local d
    for d in \
        "/c/Program Files/Git/cmd" \
        "/c/Program Files/Git/bin" \
        "/c/Program Files (x86)/Git/cmd"
    do
        if [ -f "${d}/git.exe" ]; then
            echo "${d}"
            return 0
        fi
    done
    return 1
}

function _angle_depot_env() {
    local vendor="${1:-$(pwd)/.vendor}"
    export DEPOT_TOOLS_UPDATE=0
    export DEPOT_TOOLS_WIN_TOOLCHAIN=0
    mkdir -p "${vendor}/git_cache"
    if command -v cygpath >/dev/null 2>&1; then
        export GIT_CACHE_PATH="$(cygpath -w "${vendor}/git_cache")"
    else
        export GIT_CACHE_PATH="${vendor}/git_cache"
    fi
    local git_dir
    git_dir="$(_angle_git_win_dir || true)"
    export PATH="${vendor}/depot_tools${git_dir:+:${git_dir}}:${PATH}"
}

# gclient/gn/autoninja are Win32. cmd.exe PATH must be C:\... so git.bat is found.
function _angle_win_run() {
    local vendor dt_w winpath git_dir py_dir cmd_dir cmd_file status
    vendor="$(pwd)/.vendor"
    dt_w="$(cygpath -w "${vendor}/depot_tools")"
    winpath="${dt_w}"
    git_dir="$(_angle_git_win_dir || true)"
    if [ -n "${git_dir}" ]; then
        winpath="${winpath};$(cygpath -w "${git_dir}")"
    fi
    py_dir="$(dirname "$(command -v python 2>/dev/null || true)")"
    if [ -n "${py_dir}" ] && [[ "${py_dir}" != *WindowsApps* ]]; then
        winpath="${winpath};$(cygpath -w "${py_dir}")"
    fi
    echo "angle: cmd ${*}"
    # MSYS escapes embedded quotes when passing a command string to a native
    # executable. Keep cmd syntax in a batch file rather than in argv.
    cmd_dir="$(mktemp -d)" || return 1
    cmd_file="${cmd_dir}/angle.cmd"
    printf '@echo off\r\nset "PATH=%s;%%PATH%%"\r\n%s\r\n' "$winpath" "$*" > "$cmd_file"
    status=0
    cmd.exe //d //c call "$(cygpath -w "$cmd_file")" || status=$?
    rm -f "$cmd_file"
    rmdir "$cmd_dir"
    return "$status"
}

# Chromium pins its downloaded toolchain's SDK even with local VS enabled.
# Match the scripts to the SDK actually available on the local toolchain.
function _angle_windows_sdk() {
    local root="${ANGLE_WINDOWS_SDK_ROOT:-/c/Program Files (x86)/Windows Kits/10}"
    local sdk="${WINDOWS_SDK_VERSION:-}" candidate file
    if [ -z "$sdk" ]; then
        for candidate in "$root"/Include/10.0.*; do
            if [ -f "$candidate/um/Windows.h" ] &&
               [ -f "$candidate/ucrt/stdio.h" ] &&
               [ -f "$root/Lib/${candidate##*/}/um/x64/kernel32.lib" ] &&
               [ -f "$root/Lib/${candidate##*/}/ucrt/x64/ucrt.lib" ]; then
                sdk="${candidate##*/}"
            fi
        done
    fi
    if [ -z "$sdk" ] || [ ! -f "$root/Include/$sdk/um/Windows.h" ] ||
       [ ! -f "$root/Include/$sdk/ucrt/stdio.h" ] ||
       [ ! -f "$root/Lib/$sdk/um/x64/kernel32.lib" ] ||
       [ ! -f "$root/Lib/$sdk/ucrt/x64/ucrt.lib" ]; then
        echoError "angle: no complete Windows SDK at $root (requested: $sdk)"
        return 1
    fi
    case "$sdk" in
        10.0.*) ;;
        *) echoError "angle: invalid Windows SDK version: $sdk"; return 1 ;;
    esac
    for file in build/vs_toolchain.py build/toolchain/win/setup_toolchain.py; do
        grep -q '^SDK_VERSION = ' "$file" || return 1
        sed "s/^SDK_VERSION = .*/SDK_VERSION = '$sdk'/" "$file" > "$file.sdk-tmp" || return 1
        mv "$file.sdk-tmp" "$file" || return 1
    done
    # The pinned Chromium build targets a newer SDK's NTDDI_WIN11_BR.
    # An undefined NTDDI constant evaluates to zero in SDK header guards,
    # hiding types such as FILE_INFO_BY_HANDLE_CLASS. Match WINVER's Windows
    # 10 minimum with a numeric value that also works with older installed SDKs.
    file=build/config/win/BUILD.gn
    grep -q 'NTDDI_VERSION=' "$file" || return 1
    sed 's/NTDDI_VERSION=[A-Za-z0-9_]*/NTDDI_VERSION=0x0A000000/' "$file" > "$file.sdk-tmp" || return 1
    mv "$file.sdk-tmp" "$file" || return 1
    # ANGLE's counter macros require standard argument expansion. MSVC's
    # traditional preprocessor reports C4002, which /WX makes fatal.
    if ! grep -q '/Zc:preprocessor' "$file"; then
        grep -q '"/utf-8",' "$file" || return 1
        sed 's|"/utf-8",|"/utf-8", "/Zc:preprocessor",|' "$file" > "$file.sdk-tmp" || return 1
        mv "$file.sdk-tmp" "$file" || return 1
    fi
    export WINDOWSSDKDIR="$(cygpath -w "$root")"
    echo "angle: local Windows SDK $sdk at $WINDOWSSDKDIR"
}

function prepare() {
    # Each architecture can enter prepare() without running download().
    . "$DOWNLOADER_SCRIPT"
    local vendor
    vendor="$(pwd)/.vendor"
    mkdir -p "${vendor}"
    if [ ! -d "${vendor}/depot_tools/.git" ]; then
        git -C "${vendor}" init depot_tools
        git -C "${vendor}/depot_tools" remote add origin "${DEPOT_TOOLS_URL}"
        git -C "${vendor}/depot_tools" fetch --depth=1 origin "${DEPOT_TOOLS_COMMIT}"
        git -C "${vendor}/depot_tools" checkout --force FETCH_HEAD
    fi
    verify_git_commit "${vendor}/depot_tools" "${DEPOT_TOOLS_COMMIT}"
    _angle_depot_env "${vendor}"

    # Disabling automatic updates also skips first-run setup. Initialize the
    # pinned checkout explicitly before any gclient, GN or autoninja command.
    if [ "$TYPE" = "vs" ]; then
        if ! _angle_git_win_dir >/dev/null; then
            echoError "angle: Git for Windows git.exe not found (MSYS git is not enough)."
            echoError "  winget install -e --id Git.Git"
            echoError "  Need: C:\\\\Program Files\\\\Git\\\\cmd\\\\git.exe"
            exit 1
        fi
        _angle_win_run "call \"$(cygpath -w "${vendor}/depot_tools/bootstrap/win_tools.bat")\""
        _angle_win_run "python scripts\\bootstrap.py"
        _angle_use_github_dependency_mirrors
        # ANGLE patches Chromium's pinned build dependency after sync. Later
        # platform builds reuse this checkout, so reset dependency changes
        # before syncing it again.
        _angle_win_run "gclient sync --force --no-history --shallow"
    else
        bash "${vendor}/depot_tools/ensure_bootstrap"
        python3 scripts/bootstrap.py
        _angle_use_github_dependency_mirrors
        # ANGLE patches Chromium's pinned build dependency after sync. Later
        # platform builds reuse this checkout, so reset dependency changes
        # before syncing it again.
        gclient sync --force --no-history --shallow
    fi
}

# Chromium's Gitiles mirrors can return transient 5xx errors. For dependencies
# with direct official GitHub repositories, rewrite only the mirror prefix and
# keep the DEPS commit pins unchanged. Do not rewrite Chromium subtrees such as
# LLVM libc++: those are not standalone GitHub repositories.
function _angle_use_github_dependency_mirrors() {
    local deps_file="DEPS"
    local repo
    local github_repos=(
        ARM-software/astc-encoder
        google/clspv
        google/cpu_features
        libexpat/libexpat
        KhronosGroup/EGL-Registry
        google/flatbuffers
        glmark2/glmark2
        google/googletest
        KhronosGroup/OpenCL-CTS
        KhronosGroup/OpenCL-Docs
        KhronosGroup/OpenCL-ICD-Loader
        KhronosGroup/OpenGL-Registry
        mesonbuild/meson
        google/perfetto
        KhronosGroup/VK-GL-CTS
        KhronosGroup/glslang
        LunarG/VulkanTools
        KhronosGroup/SPIRV-Cross
        KhronosGroup/SPIRV-Headers
        KhronosGroup/SPIRV-Tools
        KhronosGroup/Vulkan-Headers
        KhronosGroup/Vulkan-Loader
        KhronosGroup/Vulkan-Tools
        KhronosGroup/Vulkan-Utility-Libraries
        KhronosGroup/Vulkan-ValidationLayers
        Tencent/rapidjson
        google/re2
    )
    if ! grep -qF 'external/github.com/' "$deps_file"; then
        echoError "angle: no GitHub mirror dependencies found in DEPS"
        return 1
    fi
    for repo in "${github_repos[@]}"; do
        sed \
            -e "s#Var('chromium_git') + '/external/github.com/${repo}#'https://github.com/${repo}#g" \
            -e "s#{chromium_git}/external/github.com/${repo}#https://github.com/${repo}#g" \
            "$deps_file" > "${deps_file}.tmp" || return 1
        mv "${deps_file}.tmp" "$deps_file" || return 1
    done
    # LLVM's root repository has a matching GitHub commit; its nested libc++
    # and tool subdirectories above are split mirrors and remain on Gitiles.
    sed \
        -e "s#Var('chromium_git') + '/external/github.com/llvm/llvm-project@#'https://github.com/llvm/llvm-project@#g" \
        "$deps_file" > "${deps_file}.tmp" || return 1
    mv "${deps_file}.tmp" "$deps_file" || return 1
    # This project moved from kennethreitz/requests to psf/requests; preserve
    # the verified commit while using its current official repository.
    sed \
        -e "s#Var('chromium_git') + '/external/github.com/kennethreitz/requests#'https://github.com/psf/requests#g" \
        "$deps_file" > "${deps_file}.tmp" || return 1
    mv "${deps_file}.tmp" "$deps_file" || return 1
}

function _angle_cpu() {
    case "${ARCH}" in
        32|x86) echo "x86" ;;
        arm64|arm64ec|SIM_arm64) echo "arm64" ;;
        *) echo "x64" ;;
    esac
}

function _angle_os() {
    case "${TYPE}" in
        vs) echo "win" ;;
        osx|macos) echo "mac" ;;
        ios|tvos|catos|xros) echo "ios" ;;
        *) echoError "angle: no GN target_os for TYPE=${TYPE}"; exit 1 ;;
    esac
}

# device | simulator | catalyst — from PLATFORM (SIMULATOR*, MAC_CATALYST*) or TYPE.
function _angle_environment() {
    local p="${PLATFORM:-}"
    case "${p}" in
        *SIMULATOR*|*simulator*) echo "simulator" ; return ;;
        *CATALYST*|*catalyst*) echo "catalyst" ; return ;;
    esac
    case "${TYPE}" in
        catos) echo "catalyst" ;;
        *) echo "device" ;;
    esac
}

# Chromium's bundled clang -Werrors when -mmacos-version-min is below the
# SDK, and visionOS is not a target_platform until apple-gn.patch lands.
function _angle_patch_apple() {
    local formula_dir patch_file
    formula_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    patch_file="${formula_dir}/apple-gn.patch"
    if [ ! -f "$patch_file" ]; then
        echoError "angle: missing ${patch_file}"
        exit 1
    fi
    if grep -q 'target_platform == "xros"' build/config/ios/ios_sdk.gni 2>/dev/null &&
       grep -q 'overriding-deployment-version' build/config/mac/BUILD.gn 2>/dev/null; then
        echo "angle: apple gn patch already applied"
        return 0
    fi
    if ! patch -p1 --forward --reject-file=- < "$patch_file"; then
        echoError "angle: failed to apply apple-gn.patch"
        exit 1
    fi
}

# Complete the source/SDK guards missing from this pinned Chromium revision.
function _angle_patch_platform_sources() {
    local formula_dir
    formula_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ "$TYPE" = catos ] &&
       grep -q '^#if TARGET_OS_OSX || TARGET_OS_MACCATALYST' src/libANGLE/renderer/metal/mtl_utils.mm; then
        # Catalyst uses the existing Metal device-name fallback; IOKit lookup
        # is declared and implemented only for ANGLE_PLATFORM_MACOS.
        patch -p1 --forward --reject-file=- < "$formula_dir/catalyst-metal-vendor.patch" || return 1
    fi
    if [ "$TYPE" = catos ] &&
       ! grep -q 'sysctlbyname("hw.model"' src/common/apple_platform_utils.mm; then
        patch -p1 --forward --reject-file=- < "$formula_dir/catalyst-machine-model.patch" || return 1
    fi
    if [ "$TYPE" = xros ] &&
       ! grep -q "'xrsimulator'," build/config/apple/sdk_info.py; then
        patch -p1 --forward --reject-file=- < "$formula_dir/visionos-sdk-info.patch" || return 1
    fi
    if [ "$TYPE" = xros ]; then
        # Chromium's compiler runtime selector predates visionOS. Device and
        # simulator must use their own builtins archives, just like iOS/tvOS.
        if ! grep -q 'target_platform == "xros"' build/config/clang/BUILD.gn; then
            patch -p1 --forward --reject-file=- < "$formula_dir/visionos-clang-runtime.patch" || return 1
        fi
        # Keep the Rust allowlist consistent with apple-gn.patch's ABI names.
        # GN validates these even when ANGLE has no Rust compilation targets.
        local triple
        [ -f build/rust/known-target-triples.txt ] || return 1
        for triple in aarch64-apple-visionos aarch64-apple-visionos-sim x86_64-apple-visionos; do
            if ! grep -Fxq "$triple" build/rust/known-target-triples.txt; then
                printf '%s\n' "$triple" >> build/rust/known-target-triples.txt || return 1
            fi
        done
    fi
}

function _angle_gn_args() {
    local cpu os env apple
    cpu="$(_angle_cpu)"
    os="$(_angle_os)"
    env="$(_angle_environment)"
    local common
    common="is_debug=false is_component_build=false symbol_level=0 angle_assert_always_on=false angle_build_tests=false angle_enable_d3d9=false angle_enable_d3d12=false angle_enable_gl=false angle_enable_null=false angle_enable_vulkan=false angle_enable_essl=true angle_enable_glsl=true target_os=\"${os}\" target_cpu=\"${cpu}\""
    apple="is_clang=true use_custom_libcxx=false clang_use_chrome_plugins=false angle_enable_d3d11=false angle_enable_metal=true"
    case "${TYPE}" in
        vs)
            # MSVC does not define __BYTE_ORDER__, which Chromium's libc++ requires.
            # Siso cannot relativize C: SDK headers against a D: checkout when
            # parsing /showIncludes. Use the supported Ninja runner instead.
            echo "${common} is_clang=false use_custom_libcxx=false use_custom_libcxx_for_host=false use_siso=false angle_enable_d3d11=true angle_enable_metal=false"
            ;;
        osx|macos)
            # kIOMainPortDefault needs macOS 12.
            echo "${common} ${apple} mac_deployment_target=\"12.0\""
            ;;
        catos)
            echo "${common} ${apple} ios_enable_code_signing=false target_environment=\"catalyst\" ios_deployment_target=\"16.0\" mac_deployment_target=\"16.0\""
            ;;
        ios)
            # Dawn WorkerThread uses std::atomic::wait, available from iOS 14.
            echo "${common} ${apple} ios_enable_code_signing=false target_environment=\"${env}\" ios_deployment_target=\"15.0\""
            ;;
        tvos)
            # Let Chromium discover the tvOS SDK and its complete metadata.
            # Supplying only ios_sdk_path bypasses ios_platform_build setup.
            echo "${common} ${apple} ios_enable_code_signing=false target_environment=\"${env}\" target_platform=\"tvos\" use_blink=true ios_deployment_target=\"16.0\""
            ;;
        xros)
            # Same discovery path as tvOS. visionOS 2 is the first stable release.
            echo "${common} ${apple} ios_enable_code_signing=false target_environment=\"${env}\" target_platform=\"xros\" ios_deployment_target=\"2.0\""
            ;;
        *)
            echoError "angle: GN args not defined for TYPE=${TYPE}"
            exit 1
            ;;
    esac
}

function build() {
    local cpu outdir gn_args win_args
    cpu="$(_angle_cpu)"
    outdir="out/Release_${PLATFORM}"

    if [ "$TYPE" = "vs" ]; then
        setup_vs_vars
        export VSINSTALLDIR="${VS_INSTALL_PATH:-${VS_BASE_PATH}}"
        _angle_windows_sdk || return 1
        _angle_depot_env "$(pwd)/.vendor"
    elif [[ "$TYPE" =~ ^(osx|macos|ios|tvos|catos|xros)$ ]]; then
        _angle_depot_env "$(pwd)/.vendor"
        _angle_patch_apple
        _angle_patch_platform_sources || return 1
    else
        echoError "angle: unsupported TYPE=${TYPE}"
        exit 1
    fi

    gn_args="$(_angle_gn_args)"
    DEFINES="${gn_args}"
    echo "angle: gn=$(command -v gn 2>/dev/null || echo MISSING) --args=${gn_args}"
    if ! command -v gn >/dev/null 2>&1; then
        echoError "angle: gn not on PATH. depot_tools=$(pwd)/.vendor/depot_tools"
        ls -la "$(pwd)/.vendor/depot_tools/gn"* 2>/dev/null || true
        exit 1
    fi

    if [ "$TYPE" = "vs" ]; then
        win_args="${gn_args//\"/\\\"}"
        _angle_win_run "call gn.bat gen ${outdir} --args=\"${win_args}\""
        _angle_win_run "call autoninja.bat -C ${outdir} libEGL libGLESv2"
    else
        gn gen "${outdir}" --args="${gn_args}"
        autoninja -C "${outdir}" libEGL libGLESv2
    fi
}

function copy() {
    echo "copy angle -> $1"
    mkdir -p "$1/include" "$1/lib/$TYPE/$PLATFORM" "$1/bin/$TYPE/$PLATFORM"
    . "$SECURE_SCRIPT"

    if [ -d include ]; then
        cp -R include/. "$1/include/"
    else
        echoError "angle: include/ missing"
        exit 1
    fi

    local outdir="out/Release_${PLATFORM}"
    local copied=0
    local f
    for f in "${outdir}/libEGL.dll" "${outdir}/libGLESv2.dll" \
        "${outdir}/libEGL.dylib" "${outdir}/libGLESv2.dylib"; do
        if [ -f "$f" ]; then
            cp -v "$f" "$1/bin/$TYPE/$PLATFORM/"
            copied=1
        fi
    done
    for f in "${outdir}/libEGL.dll.lib" "${outdir}/libGLESv2.dll.lib" \
        "${outdir}/libEGL.lib" "${outdir}/libGLESv2.lib" \
        "${outdir}/libEGL.a" "${outdir}/libGLESv2.a"; do
        if [ -f "$f" ]; then
            cp -v "$f" "$1/lib/$TYPE/$PLATFORM/"
            copied=1
        fi
    done
    if [ -f "${outdir}/d3dcompiler_47.dll" ]; then
        cp -v "${outdir}/d3dcompiler_47.dll" "$1/bin/$TYPE/$PLATFORM/"
    fi
    # iOS, tvOS, Catalyst and visionOS shared targets are frameworks, not flat dylibs.
    for f in libEGL libGLESv2; do
        if [ -d "${outdir}/${f}.framework" ]; then
            rm -rf "$1/lib/$TYPE/$PLATFORM/${f}.framework"
            cp -R "${outdir}/${f}.framework" "$1/lib/$TYPE/$PLATFORM/"
            copied=1
        fi
    done

    if [ "$copied" -eq 0 ]; then
        echoError "angle: no libEGL/libGLESv2 under ${outdir}"
        ls -la "${outdir}" | head -40 || true
        exit 1
    fi

    if [ -f "$1/bin/$TYPE/$PLATFORM/libGLESv2.dll" ]; then
        secure "$1/bin/$TYPE/$PLATFORM/libGLESv2.dll" "angle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ -f "$1/bin/$TYPE/$PLATFORM/libGLESv2.dylib" ]; then
        secure "$1/bin/$TYPE/$PLATFORM/libGLESv2.dylib" "angle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ -f "$1/lib/$TYPE/$PLATFORM/libGLESv2.a" ]; then
        secure "$1/lib/$TYPE/$PLATFORM/libGLESv2.a" "angle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ -f "$1/lib/$TYPE/$PLATFORM/libGLESv2.lib" ]; then
        secure "$1/lib/$TYPE/$PLATFORM/libGLESv2.lib" "angle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    elif [ -f "$1/lib/$TYPE/$PLATFORM/libGLESv2.framework/libGLESv2" ]; then
        secure "$1/lib/$TYPE/$PLATFORM/libGLESv2.framework/libGLESv2" "angle.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS"
    fi

    if [ -d "$1/license" ]; then
        rm -rf "$1/license"
    fi
    mkdir -p "$1/license"
    if [ -f LICENSE ]; then
        cp -v LICENSE "$1/license/"
    fi
}

function clean() {
    rm -rf "out/Release_${PLATFORM}"
}

function load() {
    . "$LOAD_SCRIPT"
    if [[ "$TYPE" =~ ^(ios|tvos|catos|xros)$ ]]; then
        LOAD_RESULT=$(loadsave ${TYPE} "angle" ${ARCH} ${VER} "$LIBS_DIR_REAL/angle/lib/$TYPE/$PLATFORM" ${BUILD_ID})
    else
        LOAD_RESULT=$(loadsave ${TYPE} "angle" ${ARCH} ${VER} "$LIBS_DIR_REAL/angle/bin/$TYPE/$PLATFORM" ${BUILD_ID})
    fi
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    if [ "$PREBUILT" -eq 1 ]; then
        echo 1
    else
        TARGET_DIR="$LIBS_DIR_REAL/$1/bin/$TYPE/$PLATFORM"
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        fi
        TARGET_DIR="$LIBS_DIR_REAL/$1/lib/$TYPE/$PLATFORM"
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        fi
        echo 0
    fi
}
