#!/usr/bin/env bash
# Build the real formula, move the SDK, and link separately against full/lite.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
source "$ROOT/apothecary/formulas/protobuf/protobuf.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
case "$(uname -s)/$(uname -m)" in
    Darwin/arm64)
        TYPE=osx ARCH=arm64 PLATFORM=MAC_ARM64
        host=osx-aarch_64 protoc_sha=9cd98a532c5c5e0c4161314de0225de27e4c8a323917b6ea7b1b714d3ae23466 ;;
    Darwin/x86_64)
        TYPE=osx ARCH=x86_64 PLATFORM=MAC
        host=osx-x86_64 protoc_sha=228cc7add4616cc14ca5e80dee83209d44449a7aee95a914ae748fa374efb078 ;;
    Linux/x86_64)
        TYPE=linux ARCH=64 PLATFORM=64
        host=linux-x86_64 protoc_sha=121f6c7afe1d4d0e3ea6aab9432038599250134cbf4474cb1167d2c7decd4278 ;;
    *) echo 'This native smoke test supports macOS and Linux x86_64' >&2; exit 1 ;;
esac
export TYPE ARCH PLATFORM
export APOTHECARY_DIR="$ROOT/apothecary" DOWNLOADER_SCRIPT="$ROOT/scripts/downloader.sh"
export SECURE_SCRIPT="$ROOT/scripts/secure.sh" CPP_STANDARD=17 C_STANDARD=17
export MIN_SDK_VER=12.0 GCC_VERSION="${GCC_VERSION:-10}" PARALLEL_MAKE="${PARALLEL_MAKE:-4}"
if [ "$TYPE" = linux ]; then
    # Use the selected compiler for the consumer and metadata as well as for
    # the formula's Linux toolchain; do not fall back to the runner default.
    export CC="gcc-$GCC_VERSION" CXX="g++-$GCC_VERSION"
fi
if [ -n "${PROTOBUF_SOURCE_DIR:-}" ]; then
    cd "$PROTOBUF_SOURCE_DIR"
else
    cd "$work"
    download
    cd protobuf
fi
prepare
build
# secure.sh switches errexit off; restore it after copy, including on failure.
if ! copy "$work/original/protobuf"; then exit 1; fi
set -e
# Exercise the engine's post-copy hook too, before testing relocation.
export BUILD_DIR="$(dirname "$PWD")"
bash "$ROOT/scripts/export_config.sh" "$work/original/protobuf" "$PLATFORM" "$ARCH"
mv "$work/original" "$work/relocated"
sdk="$work/relocated/protobuf/lib/$TYPE/$PLATFORM"
source "$DOWNLOADER_SCRIPT"
for runtime in protobuf protobuf-lite; do
    digest=$(sed -n 's/^binarySha = "\([a-f0-9]*\)"/\1/p' "$sdk/lib/$runtime.pkl")
    verify_sha256 "$sdk/lib/lib$runtime.a" "$digest"
done
curl --fail --location --retry 3 -o "$work/protoc.zip" "$GIT_URL/releases/download/v$VER/protoc-$VER-$host.zip"
verify_sha256 "$work/protoc.zip" "$protoc_sha"
unzip -q "$work/protoc.zip" -d "$work/host"
mkdir -p "$work/generated"
"$work/host/bin/protoc" --proto_path="$ROOT/scripts/tests/protobuf" --cpp_out="$work/generated" full.proto lite.proto
cmake -S "$ROOT/scripts/tests/protobuf" -B "$work/consumer" -G Ninja \
    -DCMAKE_PREFIX_PATH="$sdk" -DGENERATED_DIR="$work/generated"
cmake --build "$work/consumer" --parallel "$PARALLEL_MAKE"
ctest --test-dir "$work/consumer" --output-on-failure
# Installed pkg-config files must also point at the moved SDK.
if command -v pkg-config >/dev/null 2>&1; then
    includes=$(PKG_CONFIG_PATH="$sdk/lib/pkgconfig" pkg-config --cflags protobuf)
    [[ "$includes" == *"$work/relocated/"* ]]
    [[ "$includes" != *"$work/original/"* ]]
fi
