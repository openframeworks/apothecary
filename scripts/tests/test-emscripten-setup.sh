#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/sdk/upstream/emscripten" "$fixture/wrong-path"
cat > "$fixture/sdk/upstream/emscripten/emcc" <<'EOF'
#!/usr/bin/env bash
echo 'emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 6.0.13 (fixture)'
EOF
cat > "$fixture/wrong-path/emcc" <<'EOF'
#!/usr/bin/env bash
echo 'emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 6.0.11 (wrong SDK)'
EOF
chmod +x "$fixture/sdk/upstream/emscripten/emcc" "$fixture/wrong-path/emcc"
printf 'export EMSDK_TEST_ACTIVATED=1\n' > "$fixture/sdk/emsdk_env.sh"
# A stale or absent global marker must not force another SDK installation.
git() { echo 'Unexpected git access for the already installed SDK' >&2; return 1; }
PATH="$fixture/wrong-path:$PATH"
EMSDK="$fixture/sdk"
EMSDK_VERSION=6.0.13
source "$ROOT/scripts/emscripten/setup.sh"
test "$EMSDK_TEST_ACTIVATED" = 1
test "$EMSDK_VERSION" = 6.0.13
check_emsdk "$EMSDK"
EMSDK_VERSION=6.0.11
if check_emsdk "$EMSDK"; then
    echo 'Wrong installed version accepted' >&2; exit 1
fi
if check_emsdk "$fixture/absent"; then
    echo 'Missing SDK accepted' >&2; exit 1
fi
echo 'SDK setup verifies the selected compiler, reuses the installed version and rejects mismatches'
