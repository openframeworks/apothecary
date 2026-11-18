#!/usr/bin/env bash
# Guard against baking a build-tree cacert.pem into libcurl.
# That compiled-in path is missing on user machines and produces
# CURLE_SSL_CACERT_BADFILE ("Problem with the SSL CA cert (path? access rights?)").
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CURL="$ROOT/apothecary/formulas/curl/curl.sh"
OPENSSL="$ROOT/apothecary/formulas/openssl/openssl.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }

if grep -E 'CURL_CA_BUNDLE=\$\{?CACERT_PATH' "$CURL"; then
    fail 'curl must not bake CACERT_PATH into CURL_CA_BUNDLE'
fi
if grep -E 'CURL_CA_EMBED=\$\{?CACERT_PATH|"\$CACERT_PATH"' "$CURL"; then
    fail 'curl must not bake CACERT_PATH into CURL_CA_EMBED'
fi

grep -q 'CURL_CA_NATIVE=ON' "$CURL" || fail 'Windows curl must enable CURL_CA_NATIVE'
grep -q 'USE_APPLE_SECTRUST=ON' "$CURL" || fail 'Apple curl must keep USE_APPLE_SECTRUST'
grep -q '/system/etc/security/cacerts' "$CURL" || fail 'Android curl must use the system cacerts directory'
grep -q 'CURL_CA_BUNDLE=auto' "$CURL" || fail 'Linux curl must auto-detect the distro CA bundle'
grep -q 'CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' "$CURL" || fail 'Linux cross curl must use the Debian CA bundle path'
grep -q 'cp -v cacert.pem "$1/cacert.pem"' "$CURL" || fail 'curl copy() must install cacert.pem'
grep -q 'OPENSSL_OPENSSLDIR=/etc/ssl' "$OPENSSL" || fail 'Linux OpenSSL must set OPENSSLDIR to /etc/ssl'

ca_args() {
    TYPE="$1" CROSSCOMPILING="${2:-0}" bash -c '
        set -e
        source "$1"
        curl_ca_cmake_args
    ' _ "$CURL"
}

CA_VS=$(ca_args vs)
printf '%s\n' "$CA_VS" | grep -q 'CURL_CA_NATIVE=ON' || fail "vs CA args missing native store: $CA_VS"
printf '%s\n' "$CA_VS" | grep -q 'CURL_CA_BUNDLE=none' || fail "vs CA args must not set a CA file: $CA_VS"

CA_OSX=$(ca_args osx)
printf '%s\n' "$CA_OSX" | grep -q 'CURL_CA_BUNDLE=none' || fail "osx CA args must not set a CA file: $CA_OSX"

CA_LINUX=$(ca_args linux 0)
printf '%s\n' "$CA_LINUX" | grep -q 'CURL_CA_BUNDLE=auto' || fail "linux CA args must auto-detect: $CA_LINUX"

CA_LINUX_CROSS=$(ca_args linux 1)
printf '%s\n' "$CA_LINUX_CROSS" | grep -q '/etc/ssl/certs/ca-certificates.crt' || fail "linux cross CA args must use distro path: $CA_LINUX_CROSS"

CA_ANDROID=$(ca_args android)
printf '%s\n' "$CA_ANDROID" | grep -q '/system/etc/security/cacerts' || fail "android CA args must use system cacerts: $CA_ANDROID"

echo 'curl/openssl CA defaults: no build-tree CA bundle; Windows native CA; Apple SecTrust; Android system cacerts; Linux system OPENSSLDIR'
