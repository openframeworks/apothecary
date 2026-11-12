#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/pacman" "$fixture/cache"
printf 'redirected mirror\n' > "$fixture/pacman/mirrorlist.msys"
printf 'redirected mirror\n' > "$fixture/pacman/mirrorlist.mingw"
touch "$fixture/cache/package.pkg.tar.zst" "$fixture/cache/package.pkg.tar.zst.sig"
touch "$fixture/cache/package.pkg.tar.zst.part" "$fixture/cache/package.pkg.tar.zst.sig.part"
MSYS2_PACMAN_DIR="$fixture/pacman" MSYS2_PACKAGE_CACHE="$fixture/cache" \
    bash "$ROOT/scripts/msys2/prepare-install.sh"
grep -Fxq 'Server = https://repo.msys2.org/msys/$arch/' "$fixture/pacman/mirrorlist.msys"
grep -Fxq 'Server = https://repo.msys2.org/mingw/$repo/' "$fixture/pacman/mirrorlist.mingw"
[[ -f $fixture/cache/package.pkg.tar.zst && -f $fixture/cache/package.pkg.tar.zst.sig ]]
[[ ! -e $fixture/cache/package.pkg.tar.zst.part && ! -e $fixture/cache/package.pkg.tar.zst.sig.part ]]
MSYS2_PACMAN_DIR="$fixture/pacman" MSYS2_PACKAGE_CACHE="$fixture/cache" \
    bash "$ROOT/scripts/msys2/prepare-install.sh"
echo 'MSYS2 mirror configuration and partial-download recovery passed'
