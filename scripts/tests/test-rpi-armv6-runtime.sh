#!/usr/bin/env bash
# Execute real target binaries on the Pi 1/Zero CPU, with ARMv7 as a control.
# This deliberately uses the configured sysroot rather than replacing its libc.
set -euo pipefail
: "${SYSROOT:?}" "${ARCH:?}"
[[ "$ARCH" == armv6l ]] || { echo 'This test requires ARCH=armv6l' >&2; exit 1; }
mode="${1:-system}"
root=$(cd "$(dirname "$0")/../.." && pwd)
report="${RUNNER_TEMP:-$root/build}/pi-zero-armv6/$mode"
mkdir -p "$report"
ulimit -c 0
cc="${CC:-arm-linux-gnueabihf-gcc-10}"
cxx="${CXX:-arm-linux-gnueabihf-g++-10}"
readelf="${TOOLCHAIN_PREFIX:-arm-linux-gnueabihf}-readelf"
qemu="${QEMU_ARM:-qemu-arm-static}"
flags=(--sysroot="$SYSROOT" -march=armv6zk -mcpu=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard -marm -O2)
failures=0
printf 'probe\tcpu\texit\n' >"$report/results.tsv"
{
    "$cc" --version
    "$qemu" --version
    printf 'SYSROOT=%s\n' "$SYSROOT"
    cat "$SYSROOT/etc/os-release"
} >"$report/environment.txt" 2>&1

probe() {
    local name="$1" binary="$2" cpu status
    shift 2
    "$readelf" -h -A -d "$binary" >"$report/$name.elf.txt" 2>&1
    for cpu in arm1176 cortex-a7; do
        status=0
        timeout 30s "$qemu" -cpu "$cpu" -L "$SYSROOT" "$binary" "$@" >"$report/$name.$cpu.log" 2>&1 || status=$?
        printf '%s\t%s\t%s\n' "$name" "$cpu" "$status" | tee -a "$report/results.tsv"
        cat "$report/$name.$cpu.log"
        if [[ "$status" != 0 ]]; then
            failures=$((failures + 1))
        fi
    done
}

case "$mode" in
    system)
        # No libc, startup objects or libgcc: proves ARM1176 emulation itself works.
        cat >"$report/exit.S" <<'SRC'
.syntax unified
.arm
.global _start
.type _start, %function
_start:
    mov r0, #0
    mov r7, #1
    svc #0
.section .note.GNU-stack,"",%progbits
SRC
        "$cc" "${flags[@]}" -nostdlib -static -Wl,-e,_start "$report/exit.S" -o "$report/no-libc"
        probe no-libc "$report/no-libc"
        probe sysroot-true "$SYSROOT/bin/true"
        probe sysroot-shell "$SYSROOT/bin/bash" -c 'printf "target shell runs\n"'
        cat >"$report/runtime.c" <<'SRC'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
    char *p = malloc(64);
    if (!p) return 1;
    strcpy(p, "ARMv6 C runtime");
    puts(p);
    free(p);
    return 0;
}
SRC
        "$cc" "${flags[@]}" "$report/runtime.c" -o "$report/c-runtime"
        probe c-runtime "$report/c-runtime"
        cat >"$report/runtime.cpp" <<'SRC'
#include <iostream>
#include <stdexcept>
#include <thread>
int main() {
    int value = 0;
    std::thread worker([&] { value = 42; });
    worker.join();
    try { throw std::runtime_error("ARMv6 C++ exceptions and threads"); }
    catch (const std::exception& e) { std::cout << e.what() << '\n'; }
    return value == 42 ? 0 : 1;
}
SRC
        "$cxx" "${flags[@]}" -std=c++11 -pthread "$report/runtime.cpp" -o "$report/cxx-runtime"
        probe cxx-runtime "$report/cxx-runtime"
        ;;
    package)
        archive="$root/out/openFrameworksLibs_${RELEASE:-latest}_linux_armv6l_${GCC:-gcc10}.tar.bz2"
        [[ -f "$archive" ]]
        sha256sum "$archive" >"$report/archive.sha256"
        libs=$(mktemp -d)
        trap 'rm -rf "$libs"' EXIT
        tar -xjf "$archive" -C "$libs"
        [[ -d "$libs/brotli" && -d "$libs/zlib" ]]
        cat >"$report/roundtrip.c" <<'SRC'
#include <brotli/encode.h>
#include <brotli/decode.h>
#include <zlib.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    const unsigned char input[] = "Pi Zero packaged Brotli and zlib roundtrip";
    unsigned char encoded[256], decoded[256];
    size_t encoded_size = sizeof(encoded), decoded_size = sizeof(decoded);
    if (!BrotliEncoderCompress(4, BROTLI_DEFAULT_WINDOW, BROTLI_MODE_GENERIC,
            sizeof(input), input, &encoded_size, encoded)) return 1;
    if (BrotliDecoderDecompress(encoded_size, encoded, &decoded_size, decoded) != BROTLI_DECODER_RESULT_SUCCESS) return 2;
    if (decoded_size != sizeof(input) || memcmp(input, decoded, sizeof(input))) return 3;
    uLongf zipped = sizeof(encoded), unzipped = sizeof(decoded);
    if (compress(encoded, &zipped, input, sizeof(input)) != Z_OK) return 4;
    if (uncompress(decoded, &unzipped, encoded, zipped) != Z_OK) return 5;
    if (unzipped != sizeof(input) || memcmp(input, decoded, sizeof(input))) return 6;
    puts("Packaged Brotli and zlib roundtrips passed");
    return 0;
}
SRC
        "$cc" "${flags[@]}" -I"$libs/brotli/include" -I"$libs/zlib/include" \
            "$report/roundtrip.c" \
            "$libs/brotli/lib/linux/armv6l/libbrotlienc.a" \
            "$libs/brotli/lib/linux/armv6l/libbrotlidec.a" \
            "$libs/brotli/lib/linux/armv6l/libbrotlicommon.a" \
            "$libs/zlib/lib/linux/armv6l/libz.a" -lm -o "$report/package-roundtrip"
        probe package-roundtrip "$report/package-roundtrip"
        ;;
    *) echo "Usage: $0 system|package" >&2; exit 1 ;;
esac

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
        printf '\n### Pi Zero ARMv6 %s diagnostics\n\n' "$mode"
        echo '| Probe | CPU | Exit code |'
        echo '| --- | --- | --- |'
        awk -F '\t' 'NR > 1 { printf "| %s | %s | %s |\n", $1, $2, $3 }' "$report/results.tsv"
        echo
        echo 'ARM1176 models the original Pi Zero CPU. Cortex-A7 is an ARMv7 control. This does not test the Pi GPU or physical hardware.'
    } >>"$GITHUB_STEP_SUMMARY"
fi
[[ "$failures" == 0 ]]
