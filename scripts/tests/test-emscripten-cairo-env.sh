#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/sdk/upstream/emscripten" "$fixture/wrong-path"
cat > "$fixture/sdk/emsdk_env.sh" <<'EOF'
export EMSDK_NODE="$EMSDK/sdk-node"
EOF
cat > "$fixture/sdk/upstream/emscripten/emcc" <<'EOF'
#!/usr/bin/env bash
set -eu
output=
found_platform=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -o) output=$2; shift ;;
        *.a) case "$1" in */"$EXPECTED_PLATFORM"/*) found_platform=1 ;; *) exit 1 ;; esac ;;
    esac
    shift
done
test "$found_platform" = 1
printf 'SDK compiler selected\n' > "$output"
EOF
cat > "$fixture/sdk/sdk-node" <<'EOF'
#!/usr/bin/env bash
set -eu
test -f "$1"
grep -Fx 'SDK compiler selected' "$1"
printf '%s\n' "$EXPECTED_PLATFORM" >> "$TEST_SDK_NODE_LOG"
EOF
printf '#!/usr/bin/env bash\necho "Wrong Node on PATH was selected" >&2\nexit 1\n' > "$fixture/wrong-path/node"
chmod +x "$fixture/sdk/upstream/emscripten/emcc" "$fixture/sdk/sdk-node" "$fixture/wrong-path/node"
export PATH="$fixture/wrong-path:$PATH" OUTPUT_FOLDER="$fixture/output" TEST_SDK_NODE_LOG="$fixture/node.log"
for arch in 32 64; do
    if [ "$arch" = 64 ]; then export EXPECTED_PLATFORM=WASM64; else export EXPECTED_PLATFORM=WASM; fi
    # Reproduce the CI step: only EMSDK_PATH survives, and another Node is first.
    ( unset EMSDK EMSDK_NODE; EMSDK_PATH="$fixture/sdk" ARCH="$arch" bash "$root/scripts/emscripten/test_cairo.sh" )
done
test "$(cat "$fixture/node.log")" = "$(printf 'WASM\nWASM64')"
if ( unset EMSDK EMSDK_PATH; bash "$root/scripts/emscripten/test_cairo.sh" ) > "$fixture/missing" 2>&1; then exit 1; fi
grep -F 'Set EMSDK or EMSDK_PATH' "$fixture/missing"
echo 'Cairo smoke test selects the configured SDK and its Node in a fresh shell'
