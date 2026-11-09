#!/usr/bin/env bash
# OQS OpenSSH tools. Never installs system configuration, services or host keys.
FORMULA_TYPES=("osx" "linux")
FORMULA_DEPENDS=("openssl" "liboqs" "zlib")
VER=10.4p1-oqs-2026-08
SOURCE_COMMIT=eed58298755950fb201039d00bcb37b7af1447a9
SHA256="7e4cf39caeef681574596f8849683ed2cfb048950797407754fad38ab6657ae7"
BUILD_ID=1
DEFINES=""
GIT_URL=https://github.com/open-quantum-safe/openssh

function download() {
    . "$DOWNLOADER_SCRIPT"
    downloader "$GIT_URL/archive/$SOURCE_COMMIT.tar.gz" || return $?
    verify_sha256 "$SOURCE_COMMIT.tar.gz" "$SHA256" || return $?
    tar -xf "$SOURCE_COMMIT.tar.gz" || return $?
    mv "openssh-$SOURCE_COMMIT" openssh || return $?
    rm "$SOURCE_COMMIT.tar.gz"
}

function prepare() {
    # oqs-utils.h includes sshkey.h; expose internal declarations before it.
    if ! grep -A1 '^#define SSHKEY_INTERNAL' ssh-oqs.c | grep -q '^#include "log.h"'; then
        patch -p1 < "$FORMULA_DIR/internal-api-include.patch" || return $?
    fi
    if ! grep -q 'void.*kex_reset_keys' kex.h; then
        patch -p1 < "$FORMULA_DIR/kex-reset-declaration.patch" || return $?
    fi
    if [ "$TYPE" = osx ] && ! grep -q 'AC_CHECK_DECLS(kSBXProfilePureComputation' configure.ac; then
        patch -p1 < "$FORMULA_DIR/darwin-sandbox-sdk27.patch" || return $?
    fi
    # These are relocatable tools, not a privileged system installation.
    if grep -q 'INSTALL).*4711.*ssh-keysign' Makefile.in; then
        patch -p1 < "$FORMULA_DIR/nonprivileged-install.patch" || return $?
    fi
    autoreconf -fi
}

function build() {
    local source_dir="$PWD" build_dir="$PWD/build_${TYPE}_${PLATFORM}"
    local libdir="lib/$TYPE/$PLATFORM" architecture="$ARCH"
    local platform_flags="" host_arch
    case "$TYPE" in
        osx)
            case "$PLATFORM" in MAC_ARM64) architecture=arm64 ;; MAC) architecture=x86_64 ;; *) return 1 ;; esac
            platform_flags="-arch $architecture -mmacosx-version-min=$MIN_SDK_VER"
            ;;
        linux)
            host_arch=$(uname -m)
            case "$ARCH:$host_arch" in 64:x86_64|x86_64:x86_64|arm64:aarch64|aarch64:aarch64) : ;;
                *) echoError "OpenSSH currently supports native desktop builds only"; return 1 ;; esac
            ;;
        *) echoError "Unsupported OpenSSH target: $TYPE"; return 1 ;;
    esac
    [ -f "$LIBS_DIR_REAL/liboqs/$libdir/liboqs.a" ] || { echoError "Build and copy liboqs first"; return 1; }
    [ -f "$LIBS_DIR_REAL/openssl/$libdir/libcrypto.a" ] || { echoError "Build and copy openssl first"; return 1; }
    [ -f "$LIBS_DIR_REAL/zlib/$libdir/zlib.a" ] || { echoError "Build and copy zlib first"; return 1; }
    # configure expects a conventional libz.a; keep this alias in the build tree.
    mkdir -p "$build_dir/zlib/lib" "$build_dir/zlib/include"
    cp "$LIBS_DIR_REAL/zlib/$libdir/zlib.a" "$build_dir/zlib/lib/libz.a" || return $?
    cp -R "$LIBS_DIR_REAL/zlib/include/." "$build_dir/zlib/include/" || return $?
    (
        cd "$build_dir" || exit 1
        CC="${CC:-cc}" CFLAGS="-O2 $platform_flags" \
        CPPFLAGS="-I$LIBS_DIR_REAL/openssl/include -I$LIBS_DIR_REAL/liboqs/include" \
        LDFLAGS="$platform_flags" \
        "$source_dir/configure" --prefix=/ --sysconfdir=/etc/ssh \
            --libexecdir=/libexec/oqs-openssh \
            --with-ssl-dir="$LIBS_DIR_REAL/openssl/$libdir" \
            --with-liboqs-dir="$LIBS_DIR_REAL/liboqs/$libdir" \
            --with-zlib="$build_dir/zlib" \
            --without-pam --without-selinux --without-kerberos5 \
            --without-libedit --without-security-key-builtin --disable-strip || exit $?
        make -j"${PARALLEL_MAKE:-4}" || exit $?
        make DESTDIR="$build_dir/Release" install-nosysconf
    )
}

function copy() {
    local prefix="build_${TYPE}_${PLATFORM}/Release"
    local bindir="$1/bin/$TYPE/$PLATFORM" helperdir="$1/libexec/$TYPE/$PLATFORM"
    local binary
    [ -x "$prefix/bin/ssh" ] && [ -x "$prefix/sbin/sshd" ] || return 1
    mkdir -p "$bindir" "$helperdir" "$1/share/$TYPE/$PLATFORM" "$1/license"
    cp -R "$prefix/bin/." "$bindir/" || return $?
    cp -R "$prefix/sbin/." "$bindir/" || return $?
    cp -R "$prefix/libexec/oqs-openssh/." "$helperdir/" || return $?
    cp -R "$prefix/share/." "$1/share/$TYPE/$PLATFORM/" || return $?
    cp LICENCE "$1/license/" || return $?
    # sshd's split processes need relocated helper paths. The launcher supplies
    # them explicitly; callers still choose their own configuration and keys.
    cat > "$bindir/oqs-sshd" <<'LAUNCHER'
#!/usr/bin/env bash
set -e
bindir=$(cd "$(dirname "$0")" && pwd -P)
platform=$(basename "$bindir")
type=$(basename "$(dirname "$bindir")")
root=$(cd "$bindir/../../.." && pwd -P)
exec "$bindir/sshd" \
    -o "SshdAuthPath=\"$root/libexec/$type/$platform/sshd-auth\"" \
    -o "SshdSessionPath=\"$root/libexec/$type/$platform/sshd-session\"" "$@"
LAUNCHER
    chmod +x "$bindir/oqs-sshd" || return $?
    # These dependencies are embedded in the module/tools; retain their notices.
    mkdir -p "$1/license/openssl" || return $?
    cp -R "$LIBS_DIR_REAL/openssl/license/." "$1/license/openssl/" || return $?
    mkdir -p "$1/license/liboqs" || return $?
    cp -R "$LIBS_DIR_REAL/liboqs/license/." "$1/license/liboqs/" || return $?
    mkdir -p "$1/license/zlib" || return $?
    cp -R "$LIBS_DIR_REAL/zlib/license/." "$1/license/zlib/" || return $?
    . "$SECURE_SCRIPT"
    for binary in ssh sshd ssh-keygen scp sftp ssh-agent ssh-add ssh-keyscan; do
        [ -x "$bindir/$binary" ] || return 1
        secure "$bindir/$binary" "$binary.pkl" "$VER" "$DEFINES" "$BUILD_ID" "${FORMULA_DEPENDS[*]}" "$SOURCE_COMMIT" || return $?
    done
}

function clean() {
    local build_dir="build_${TYPE}_${PLATFORM}"
    if [ -d "$build_dir" ]; then rm -r "$build_dir"; fi
}
function load() { echo 0; }
