#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../check-sdk-versions.sh"
# Provider/real-YAML fixtures are separate; publication tests stay offline.
sdk_toolchains() { echo '{"markdown":"","checks":0,"errors":0,"updates":0}'; }
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
original_root=$ROOT
mkdir -p "$fixture/.github/workflows" "$fixture/scripts"
cp "$ROOT/scripts/sdk-versions.json" "$fixture/scripts/sdk-versions.json"
ROOT=$fixture
entry=$(jq -c '.[0]' "$ROOT/scripts/sdk-versions.json")
pin_file="$ROOT/.github/workflows/build-emscripten.yml"
printf 'env:\n  EMSDK_VERSION: "6.0.13"\n' > "$pin_file"
pin=$(sdk_current "$entry")
jq -en --argjson pin "$pin" '$pin == {pin:"6.0.13",version:[6,0,13,0]}' >/dev/null
for value in '"6.0.13-rc1"' 'latest' '\$(touch should-not-execute)' ''; do
    printf 'env:\n  EMSDK_VERSION: %s\n' "$value" > "$pin_file"
    if sdk_current "$entry" >/dev/null 2>&1; then echo "Invalid SDK pin accepted: $value" >&2; exit 1; fi
done
test ! -e should-not-execute
printf 'env:\n  EMSDK_VERSION: "6.0.13"\n  EMSDK_VERSION: "6.0.12"\n' > "$pin_file"
if sdk_current "$entry" >/dev/null 2>&1; then echo 'Ambiguous SDK pin accepted' >&2; exit 1; fi
printf 'env:\n  EMSDK_VERSION: "6.0.11"\n' > "$pin_file"
(
    api() { echo '[{"tag_name":"6.0.13","html_url":"https://example.test/6.0.13"},{"tag_name":"6.0.14-rc1","prerelease":true}]'; }
    GITHUB_STEP_SUMMARY="$fixture/summary" sdk_main
) > "$fixture/report"
grep -Fq '| Emscripten | 6.0.11 | [6.0.13](https://example.test/6.0.13) | Update available |' "$fixture/report"
grep -Fq '1 successful checks; 0 failed; 1 updates available.' "$fixture/report"
cmp "$fixture/report" "$fixture/summary"
printf 'env:\n  EMSDK_VERSION: "6.0.13"\n' > "$pin_file"
# A healthy SDK check still creates its own report; the vendor-library issue
# returned by the API must never be selected for editing.
(
    api() {
        if [[ ${3:-GET} != GET ]]; then
            jq -cn --arg path "$1" --arg method "$3" --argjson payload "$4" '{path:$path,method:$method,payload:$payload}' >> "$fixture/writes"
            echo '{}'; return
        fi
        case $1 in
            repos/emscripten-core/emscripten/releases*) echo '[{"tag_name":"6.0.13","html_url":"https://example.test/6.0.13"}]' ;;
            repos/owner/project/issues*) echo '[{"number":612,"body":"<!-- apothecary-upstream-versions -->"}]' ;;
            *) echo "Unexpected mock API path: $1" >&2; return 1 ;;
        esac
    }
    sdk_main --file-issue --repository owner/project
) > "$fixture/current"
grep -Fq '| Up to date |' "$fixture/current"
jq -e '.method == "POST" and .path == "repos/owner/project/issues" and
    (.payload.body | contains("<!-- apothecary-sdk-versions -->")) and
    .payload.title == "Apothecary SDK version check"' "$fixture/writes" >/dev/null
# Existing SDK issues are updated, with a distinct marker and no duplicate issue.
(
    api() {
        if [[ ${3:-GET} != GET ]]; then
            printf '%s %s\n' "$3" "$1" > "$fixture/update"; echo '{}'; return
        fi
        jq -cn --arg marker "$MARKER" '[{number:700,body:$marker}]'
    }
    publish owner/project 'new SDK report' 0 0 1
)
grep -Fxq 'PATCH repos/owner/project/issues/700' "$fixture/update"
if (
    candidates() { echo 'HTTP 503 from SDK upstream' >&2; return 1; }
    sdk_main
) > "$fixture/failed"; then echo 'Failed lookup returned success' >&2; exit 1; fi
grep -Fq 'HTTP 503 from SDK upstream' "$fixture/failed"
grep -Fq 'No successful checks' "$fixture/failed"
grep -Fq '0 successful checks; 1 failed' "$fixture/failed"
if (
    candidates() { echo '[{"tag":"6.0.13","url":"https://example.test/sdk"}]'; }
    sdk_toolchains() { echo '{"markdown":"Toolchain fixture failed visibly","checks":2,"errors":1,"updates":1}'; }
    sdk_main
) > "$fixture/toolchain-failed"; then echo 'Failed toolchain lookup returned success' >&2; exit 1; fi
grep -Fq 'Toolchain fixture failed visibly' "$fixture/toolchain-failed"
grep -Fq '3 successful checks; 1 failed; 1 updates available' "$fixture/toolchain-failed"
echo 'SDK reports: literal pins, stable releases, status tables, issue isolation and failure reporting passed'
