#!/usr/bin/env bash
#
# GLon12 — Mesa Gallium OpenGL → D3D12 (Microsoft OpenGLOn12)
# https://docs.mesa3d.org/drivers/d3d12.html
#
# Brought forward from origin/openGLonDX12 @ 44174899.
# VS-only. Ships opengl32.dll + libgallium_wgl.dll + dxil.dll next to the OF .exe so
# GLFW/GLEW keep working; the system OpenGL ICD is not used.
#
# Host needs: meson, ninja (or Meson VS backend + MSBuild), WinFlexBison
# (formula downloads the latter). Windows 10+ D3D12 runtime.

FORMULA_TYPES=("vs")
FORMULA_DEPENDS=()

VER=26.2.5
SHA256=794b3d1729075dae7ebd47c7283b7ca0cdb5dec668f7f11cc0a5d82f6138a0a5
WINFLEX_VER=2.5.25
WINFLEX_SHA256=8d324b62be33604b2c45ad1dd34ab93d722534448f55a16ca7292de32b6ac135
BUILD_ID=15
DEFINES="-Dgallium-drivers=d3d12 -Dllvm=disabled -Dplatforms=windows"

GIT_URL=https://gitlab.freedesktop.org/mesa/mesa

function _glon12_sdk_root() {
    local root="${GLON12_WINDOWS_SDK_ROOT:-${WindowsSdkDir:-${WINDOWSSDKDIR:-/c/Program Files (x86)/Windows Kits/10}}}"
    if command -v cygpath >/dev/null 2>&1; then
        root=$(cygpath -u "$root") || return 1
    fi
    printf '%s\n' "${root%/}"
}

function _glon12_sdk_version() {
    local root="$1" version
    version="${GLON12_WINDOWS_SDK_VERSION:-${WindowsSDKVersion:-${WINDOWSSDKVERSION:-}}}"
    version="${version%\\}"
    version="${version%/}"
    if [ -z "$version" ]; then
        version=$(ls -1 "$root/Lib" 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -1) || return 1
    fi
    if [ -z "$version" ] || [ ! -d "$root/Lib/$version" ]; then
        echo "glon12: Windows SDK version not installed: $root/Lib/$version" >&2
        return 1
    fi
    printf '%s\n' "$version"
}

function _glon12_dxil_arch() {
    case "$ARCH" in
        32|x86) echo x86 ;;
        64|x64|x86_64|arm64ec) echo x64 ;;
        arm64) echo arm64 ;;
        *) echo "glon12: unsupported DXIL runtime architecture $ARCH" >&2; return 1 ;;
    esac
}

# download the source code and unpack it into LIB_NAME
function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "https://archive.mesa3d.org/mesa-${VER}.tar.xz"
    verify_sha256 "mesa-${VER}.tar.xz" "$SHA256"
    tar -xf "mesa-${VER}.tar.xz"
    mv "mesa-${VER}" glon12
    rm "mesa-${VER}.tar.xz"
}

function prepare() {
    if [ -d "/c/Program Files/Meson" ]; then
        export PATH="/c/Program Files/Meson:$PATH"
    fi
    if ! command -v meson >/dev/null 2>&1; then
        echoError "glon12: meson not on PATH (install meson + ninja, or the Meson MSI)"
        exit 1
    fi

    # Mesa 26: Python 3.12 dropped distutils. meson.build requires packaging or distutils.
    local py
    py=""
    if command -v python >/dev/null 2>&1; then
        py="$(command -v python)"
    elif command -v python3 >/dev/null 2>&1; then
        py="$(command -v python3)"
    fi
    if [ -n "$py" ]; then
        if ! "$py" -c "import packaging" >/dev/null 2>&1 && ! "$py" -c "import distutils" >/dev/null 2>&1; then
            echo "glon12: installing Python packaging/mako (Mesa meson)"
            "$py" -m pip install --upgrade packaging mako pyyaml setuptools || true
        fi
        if ! "$py" -c "import packaging" >/dev/null 2>&1 && ! "$py" -c "import distutils" >/dev/null 2>&1; then
            echoError "glon12: Python packaging module missing. Run: \"$py\" -m pip install packaging mako"
            exit 1
        fi
    fi

    . "$DOWNLOADER_SCRIPT"
    downloader "https://github.com/lexxmark/winflexbison/releases/download/v${WINFLEX_VER}/win_flex_bison-${WINFLEX_VER}.zip"
    verify_sha256 "win_flex_bison-${WINFLEX_VER}.zip" "$WINFLEX_SHA256"
    mkdir -p winflexbison
    unzip -q "win_flex_bison-${WINFLEX_VER}.zip" -d winflexbison
    rm -f "win_flex_bison-${WINFLEX_VER}.zip"
    export PATH="$(pwd)/winflexbison:${PATH}"
}

# Mesa 26 has no CMake/SCons. Meson is required. Run it from bash (MSYS
# meson is a Python script — cmd.exe cannot launch it). Do not use a .bat.
function build() {
    if [ "$TYPE" != "vs" ]; then
        echoError "glon12 is VS-only"
        exit 1
    fi

    setup_vs_vars
    export VSINSTALLDIR="${VS_INSTALL_PATH:-${VS_BASE_PATH}}"

    # Core maps arm64ec → Host*/arm64. Prefer the real ARM64EC toolset
    # when installed; otherwise /arm64EC selects the ABI on the ARM64 compiler.
    if [ "$ARCH" = "arm64ec" ]; then
        local ec_bin
        ec_bin="$(cd "${VS_BIN_PATH}/../arm64ec" 2>/dev/null && pwd)" || ec_bin=""
        if [ -n "$ec_bin" ] && [ -f "${ec_bin}/cl.exe" ]; then
            VS_BIN_PATH="$ec_bin"
            echo "glon12: ARM64EC toolset ${VS_BIN_PATH}"
        else
            echoWarning "glon12: no Host*/arm64ec/cl.exe; using ${VS_BIN_PATH} + /arm64EC"
        fi
    fi

    local bdir="build_${TYPE}_${PLATFORM}"
    rm -rf "${bdir}"
    mkdir -p "${bdir}"

    local lib_arch msvc_root kits kitver
    lib_arch="$(basename "${VS_BIN_PATH}")"
    # MSVC and Windows SDK ship the hybrid ARM64/ARM64EC runtime and import
    # libraries under arm64, even when the compiler lives in bin/*/arm64ec.
    if [ "$ARCH" = "arm64ec" ]; then
        lib_arch="arm64"
    fi
    msvc_root="$(cd "${VS_BIN_PATH}/../../.." && pwd)"
    kits=$(_glon12_sdk_root) || return 1
    kitver=$(_glon12_sdk_version "$kits") || return 1

    local inc_w lib_w
    inc_w="$(cygpath -w "${msvc_root}/include")"
    lib_w="$(cygpath -w "${msvc_root}/lib/${lib_arch}")"
    if [ -n "${kitver}" ]; then
        inc_w="${inc_w};$(cygpath -w "${kits}/Include/${kitver}/ucrt");$(cygpath -w "${kits}/Include/${kitver}/um");$(cygpath -w "${kits}/Include/${kitver}/shared");$(cygpath -w "${kits}/Include/${kitver}/winrt")"
        lib_w="${lib_w};$(cygpath -w "${kits}/Lib/${kitver}/ucrt/${lib_arch}");$(cygpath -w "${kits}/Lib/${kitver}/um/${lib_arch}")"
    fi
    export INCLUDE="${inc_w}${INCLUDE:+;${INCLUDE}}"
    export LIB="${lib_w}${LIB:+;${LIB}}"
    export LIBPATH="${lib_w}${LIBPATH:+;${LIBPATH}}"

    # MSVC cl/link before Git/MSYS /usr/bin/link.exe
    export PATH="${VS_BIN_PATH}:$(pwd)/winflexbison:${PATH}"
    export CC="${VS_BIN_PATH}/cl.exe"
    export CXX="${VS_BIN_PATH}/cl.exe"
    export LD="${VS_BIN_PATH}/link.exe"
    # Mesa adds /we4189. NDEBUG makes assert-only locals unused (C4189).
    # _CL_ is appended after the compiler command, so it beats /we4189.
    # MSYS otherwise converts slash-prefixed environment flags into paths
    # before launching native Meson/Python (e.g. /wd4189 becomes wd4189.obj).
    export MSYS2_ENV_CONV_EXCL="${MSYS2_ENV_CONV_EXCL:+${MSYS2_ENV_CONV_EXCL};}CL;_CL_"
    export _CL_="${_CL_:+${_CL_} }/wd4189"
    if [ "$ARCH" = "arm64ec" ]; then
        export _CL_="${_CL_} /arm64EC"
    fi

    echo "glon12: CC=${CC}"
    echo "glon12: LIB=${LIB}"
    if [ ! -f "${msvc_root}/lib/${lib_arch}/msvcrt.lib" ]; then
        echoError "glon12: missing ${msvc_root}/lib/${lib_arch}/msvcrt.lib"
        exit 1
    fi

    # Meson host_machine follows the meson/Python process, not cl.exe.
    # ARM64 Windows + ARCH=64 would compile blake3_neon.c with x64 cl (C1189).
    local cpu_family cpu
    case "${ARCH}" in
        32|x86) cpu_family="x86"; cpu="i686" ;;
        arm64) cpu_family="aarch64"; cpu="aarch64" ;;
        arm64ec) cpu_family="aarch64"; cpu="arm64ec" ;;
        *) cpu_family="x86_64"; cpu="x86_64" ;;
    esac
    local host_m host_family
    host_m="$(python -c "import platform; print(platform.machine())" 2>/dev/null || uname -m)"
    host_m="$(echo "${host_m}" | tr '[:upper:]' '[:lower:]')"
    case "${host_m}" in
        aarch64|arm64) host_family="aarch64" ;;
        x86_64|amd64) host_family="x86_64" ;;
        x86|i686|i386) host_family="x86" ;;
        *) host_family="${host_m}" ;;
    esac
    local cl_w
    cl_w="$(cygpath -w "${VS_BIN_PATH}/cl.exe")"
    # Next to the build dir — meson setup rejects a non-empty build dir.
    local machine_ini="meson-cpu-${PLATFORM}.ini"
    {
        echo "[binaries]"
        echo "c = '${cl_w}'"
        echo "cpp = '${cl_w}'"
        echo
        echo "[host_machine]"
        echo "system = 'windows'"
        echo "cpu_family = '${cpu_family}'"
        echo "cpu = '${cpu}'"
        echo "endian = 'little'"
        if [ "$ARCH" = "arm64ec" ]; then
            echo
            echo "[built-in options]"
            echo "c_link_args = ['/machine:arm64ec']"
            echo "cpp_link_args = ['/machine:arm64ec']"
        fi
    } > "${machine_ini}"
    echo "glon12: meson cpu_family=${cpu_family} (ARCH=${ARCH}) host=${host_family} file=${machine_ini}"

    # Ninja derives lib.exe /MACHINE from cl's banner, which still says ARM64
    # with /arm64EC. The VS backend honors host_machine.cpu=arm64ec for both
    # DLLs and the static libraries in Mesa subprojects.
    local backend=ninja
    [ "$ARCH" != arm64ec ] || backend=vs
    local meson_args=(
        setup "${bdir}"
        --backend="$backend"
        --buildtype=release
        --prefix="$(pwd)/${bdir}/Release"
        -Dgallium-drivers=d3d12
        -Dgallium-d3d12-video=disabled
        -Dzlib=disabled
        -Dllvm=disabled
        -Dplatforms=windows
        -Dbuild-tests=false
    )
    if [ "${host_family}" = "${cpu_family}" ]; then
        meson_args+=(--native-file "${machine_ini}")
    else
        meson_args+=(--cross-file "${machine_ini}")
    fi
    if [ "$backend" = vs ]; then
        # Meson launches msbuild by name. setup_vs_vars discovers VS but does
        # not add MSBuild's directory to PATH for the native Python process.
        local vs_root msbuild_dir
        vs_root="$(cygpath -u "$VS_INSTALL_PATH")"
        for msbuild_dir in "$vs_root/MSBuild/Current/Bin" "$vs_root/MSBuild/${VS_VER:-17}.0/Bin"; do
            if [ -f "$msbuild_dir/MSBuild.exe" ]; then
                export PATH="$msbuild_dir:$PATH"
                break
            fi
        done
        if ! command -v MSBuild.exe >/dev/null 2>&1; then
            echoError "glon12: MSBuild.exe not found under $vs_root/MSBuild"
            return 1
        fi
    fi
    # --vsenv is nice on a working VS; CI MSYS meson + our INCLUDE/LIB is enough.
    if ! meson "${meson_args[@]}" --vsenv; then
        echoWarning "glon12: meson --vsenv failed, retrying with INCLUDE/LIB only"
        rm -rf "${bdir}"
        mkdir -p "${bdir}"
        meson "${meson_args[@]}"
    fi
    meson compile -C "${bdir}" -j "${PARALLEL_MAKE}"
    meson install -C "${bdir}"
}

function copy() {
    echo "copy glon12 -> $1"
    local kits kitver runtime_arch validator destination
    kits=$(_glon12_sdk_root) || return 1
    kitver=$(_glon12_sdk_version "$kits") || return 1
    runtime_arch=$(_glon12_dxil_arch) || return 1
    # ARM64EC can load the SDK's x64 validator; a pure ARM64 DLL uses a
    # different ABI. The SDK does not ship a separate arm64ec bin directory.
    validator="$kits/bin/$kitver/$runtime_arch/dxil.dll"
    if [ ! -s "$validator" ]; then
        echo "glon12: required DXIL shader validator missing: $validator" >&2
        return 1
    fi
    destination="$1/bin/$TYPE/$PLATFORM"
    mkdir -p "$1/include" "$destination" "$1/lib/$TYPE/$PLATFORM" || return 1
    . "$SECURE_SCRIPT"

    local bdir="build_${TYPE}_${PLATFORM}"
    local copied=0
    local f
    while IFS= read -r f; do
        cp -v "$f" "$destination/" || return 1
        copied=1
    done < <(find "${bdir}" -type f \( -iname 'opengl32.dll' -o -iname 'libgallium_wgl.dll' -o -iname 'libglapi.dll' \) 2>/dev/null)

    if [ "$copied" -eq 0 ]; then
        echoError "glon12: no opengl32.dll / libgallium_wgl.dll under ${bdir}"
        find "${bdir}" -iname '*.dll' | head -40 || true
        exit 1
    fi

    for f in opengl32.dll libgallium_wgl.dll; do
        if [ ! -s "$destination/$f" ]; then
            echo "glon12: required Mesa runtime missing: $destination/$f" >&2
            return 1
        fi
    done
    cp -v "$validator" "$destination/dxil.dll" || return 1
    secure "$destination/opengl32.dll" "glon12.pkl" "$VERSION" "$DEFINES" "$BUILD_ID" "$FORMULA_DEPENDS" "$SHA256" || return 1
    {
        pkl_property windowsSdkVersion "$kitver"
        pkl_property dxilSdkArchitecture "$runtime_arch"
        pkl_property dxilBinary "dxil.dll"
        pkl_property dxilBinarySha "$(calculate_hash "$destination/dxil.dll")"
        pkl_property dxilShaType "$(hash_type "$destination/dxil.dll")"
    } >> "$destination/glon12.pkl" || return 1

    if [ -d "$1/license" ]; then
        rm -rf "$1/license"
    fi
    mkdir -p "$1/license"
    if [ -f docs/license.rst ]; then
        cp -v docs/license.rst "$1/license/"
    elif [ -f LICENSE ]; then
        cp -v LICENSE "$1/license/"
    fi
}

function clean() {
    rm -rf "build_${TYPE}_${PLATFORM}"
}

function load() {
    . "$LOAD_SCRIPT"
    LOAD_RESULT=$(loadsave ${TYPE} "glon12" ${ARCH} ${VER} "$LIBS_DIR_REAL/glon12/bin/$TYPE/$PLATFORM" ${BUILD_ID})
    PREBUILT=$(echo "$LOAD_RESULT" | tail -n 1)
    local runtime_dir="$LIBS_DIR_REAL/glon12/bin/$TYPE/$PLATFORM"
    if [ "$PREBUILT" -eq 1 ] && [ -s "$runtime_dir/opengl32.dll" ] &&
       [ -s "$runtime_dir/libgallium_wgl.dll" ] && [ -s "$runtime_dir/dxil.dll" ]; then
        echo 1
    else
        TARGET_DIR="$LIBS_DIR_REAL/$1/bin/$TYPE/$PLATFORM"
        if [ -d "$TARGET_DIR" ]; then
            echoInfo "Deleting existing folder: $TARGET_DIR"
            rm -rf "$TARGET_DIR"
        fi
        echo 0
    fi
}
