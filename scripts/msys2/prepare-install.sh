#!/usr/bin/env bash
# Run before package transactions, after the base MSYS2 shell is available.
set -euo pipefail
pacman_dir=${MSYS2_PACMAN_DIR:-/etc/pacman.d}
cache_dir=${MSYS2_PACKAGE_CACHE:-/var/cache/pacman/pkg}

# The redirector can choose slow/out-of-sync mirrors; use the official origin.
# Leave pacman.conf and its signature checks unchanged.
printf '%s\n' 'Server = https://repo.msys2.org/msys/$arch/' > "$pacman_dir/mirrorlist.msys"
printf '%s\n' 'Server = https://repo.msys2.org/mingw/$repo/' > "$pacman_dir/mirrorlist.mingw"

# Resuming a failed transfer from another mirror caused HTTP 416 failures.
# Preserve complete cached packages and signatures; discard only partial files.
if [[ -d $cache_dir ]]; then
    find "$cache_dir" -type f -name '*.part' -print -delete
fi
