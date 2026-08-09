#!/usr/bin/env bash
set -euo pipefail

archive=${1:?usage: validate-release-archive.sh ARCHIVE EXPECTED_PATH EXPECTED_MACHINE}
expected_path=${2:?expected archive path required}
expected_machine=${3:?expected machine pattern required}

test -f "$archive"
test -f "${archive}.sha256"
test -f "${archive}.manifest.json"
(cd "$(dirname "$archive")" && sha256sum -c "$(basename "$archive").sha256")

if ! tar -tjf "$archive" | grep -Eq "^[^/]+/${expected_path}[^/]+"; then
    echo "Archive does not contain the expected ${expected_path} payload." >&2
    exit 1
fi
if tar -tjf "$archive" | grep -Eq '/lib/(linux64|linuxarmv6l|linuxaarch64)/'; then
    echo "Archive contains a forbidden legacy Linux path." >&2
    exit 1
fi

extract_dir=$(mktemp -d)
trap 'rm -rf "$extract_dir"' EXIT
tar -xjf "$archive" -C "$extract_dir"

found=0
while IFS= read -r binary; do
    found=1
    file "$binary" | grep -Eq "$expected_machine"
    if [[ "$binary" == *.so || "$binary" == *.so.* ]]; then
        if readelf -d "$binary" | grep -E 'RPATH|RUNPATH'; then
            echo "Unexpected runtime search path in $binary" >&2
            exit 1
        fi
        readelf -d "$binary" | grep 'NEEDED' || true
        objdump -T "$binary" | grep -Eo 'GLIBC(X{2})?_[0-9.]+' | sort -Vu | tail -1 || true
    else
        member=$(ar t "$binary" | head -1)
        member_dir=$(mktemp -d)
        (cd "$member_dir" && ar x "$binary" "$member")
        file "$member_dir/$member" | grep -Eq "$expected_machine"
        rm -rf "$member_dir"
    fi
    if strings "$binary" | grep -Eq '/(home/runner/work|__w)/'; then
        echo "Archive contains an unexpected host path in $binary" >&2
        exit 1
    fi
done < <(find "$extract_dir" -type f \( -name '*.a' -o -name '*.so' -o -name '*.so.*' \) -print)

if [ "$found" -eq 0 ]; then
    echo "Archive contains no libraries to inspect." >&2
    exit 1
fi
