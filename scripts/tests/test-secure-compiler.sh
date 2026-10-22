#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/compiler tools" "$fixture/output"
cat > "$fixture/compiler tools/cl.exe" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = --version ]; then exit 2; fi
echo 'Microsoft (R) C/C++ Optimizing Compiler Version fixture for x64' >&2
exit 2
EOF
chmod +x "$fixture/compiler tools/cl.exe"
printf 'binary fixture\n' > "$fixture/output/example.lib"
TYPE=vs VER=1.0 CPP_STANDARD=17 C_STANDARD=17 GIT_URL=https://example.invalid/source
source "$ROOT/scripts/secure.sh"
set -euo pipefail
CXX="$fixture/compiler tools/cl.exe"
secure "$fixture/output/example.lib" example.pkl "$VER" '' 1 '' > /dev/null
grep -Fx "compiler = \"$CXX\"" "$fixture/output/example.pkl"
grep -Fx 'compilerVersion = "Microsoft (R) C/C++ Optimizing Compiler Version fixture for x64"' "$fixture/output/example.pkl"
# An unavailable optional compiler probe must still leave complete metadata.
CXX=apothecary-missing-compiler-fixture
secure "$fixture/output/example.lib" example.pkl "$VER" '' 1 '' > /dev/null
grep -Fx 'compilerVersion = ""' "$fixture/output/example.pkl"
grep -Eq '^binarySha = "[0-9a-f]{32,128}"$' "$fixture/output/example.pkl"
echo 'Compiler metadata preserves executable paths, supports MSVC and tolerates unavailable probes'
