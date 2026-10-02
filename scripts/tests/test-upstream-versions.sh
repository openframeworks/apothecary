#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../check-upstream-versions.sh"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT
passed=0
assert() {
    if "$@"; then passed=$((passed + 1)); else echo "FAIL: $*" >&2; exit 1; fi
}
entry='{"repo":"owner/project","pattern":"v?(\\d+(?:\\.\\d+)+)"}'
assert json -en 'include "upstream-versions"; ("1.10" | version("(\\d+(?:\\.\\d+)+)")) > ("1.9.9" | version("(\\d+(?:\\.\\d+)+)"))' >/dev/null
assert json -en 'include "upstream-versions"; ("1.2" | version("(\\d+(?:\\.\\d+)+)")) == ("1.2.0" | version("(\\d+(?:\\.\\d+)+)"))' >/dev/null
for tag in v1.2.3-rc1 v1.2.3-beta master deadbeef v1.2.3-dev; do
    assert json -en --arg tag "$tag" 'include "upstream-versions"; ($tag | version("v?(\\d+(?:\\.\\d+)+)")) == null' >/dev/null
done
assert json -en 'include "upstream-versions"; ("VER-2-14-3" | version("VER-(\\d+(?:-\\d+)+)")) == [2,14,3,0] and ("curl-8_22_0" | version("curl-(\\d+(?:_\\d+)+)")) == [8,22,0,0]' >/dev/null
assert json -en 'include "upstream-versions"; {pattern:"(\\d+(?:\\.\\d+)+)",even_components:[1,2]} as $e | ("1.19.2" | stable_version($e)) == null and ("1.18.3" | stable_version($e)) == null and ("1.18.4" | stable_version($e)) != null' >/dev/null
# API mocks run in subshells: no network calls or real issue writes.
choices=$(
    api() { printf '%s' '[{"tag_name":"v3.0.0","prerelease":true},{"tag_name":"v4.0.0","draft":true},{"tag_name":"v1.9.0"},{"tag_name":"v1.10.0"}]'; }
    candidates "$entry"
)
assert jq -en --argjson rows "$choices" '$rows | map(.tag) == ["v1.9.0","v1.10.0"]' >/dev/null
choices=$(
    api() {
        case $1 in
            (*releases*page=1) jq -cn '[range(100) | {tag_name:"v1.0.0"}]' ;;
            (*releases*page=2) echo '[{"tag_name":"v2.0.0"}]' ;;
            (*) return 1 ;;
        esac
    }
    candidates "$entry"
)
assert jq -en --argjson rows "$choices" '$rows | any(.tag == "v2.0.0")' >/dev/null
choices=$(
    api() { case $1 in (*releases*) echo '[]';; (*) echo '[{"name":"v1.2.0"},{"name":"v9.0.0-rc1"}]';; esac; }
    candidates "$entry"
)
assert jq -en --argjson rows "$choices" '$rows == [{tag:"v1.2.0",url:"https://github.com/owner/project/tree/v1.2.0"}]' >/dev/null
choices=$(
    api() { echo '[{"tag_name":"1.18.4"}]'; }
    candidates '{"repo":"cairo/cairo","provider":"gitlab","pattern":"(\\d+(?:\\.\\d+)+)"}'
)
assert jq -en --argjson rows "$choices" '$rows[0].url == "https://gitlab.freedesktop.org/cairo/cairo/-/tags/1.18.4"' >/dev/null
assert json -en 'include "upstream-versions";
  {url:"https://archive.mesa3d.org/",pattern:"(\\d+(?:\\.\\d+)+)",filename_pattern:"mesa-(\\d+\\.\\d+\\.\\d+)\\.tar\\.xz"} as $e |
  "<a href=\"mesa-26.2.4.tar.xz\">release</a><a href=\"mesa-27.0.0-rc1.tar.xz\">rc</a><a href=\"mesa-26.2.4.tar.xz.sig\">sig</a>" |
  archive_rows($e) == [{tag:"26.2.4",url:"https://archive.mesa3d.org/mesa-26.2.4.tar.xz"}]' >/dev/null
mkdir -p "$TEST_TMP/formulas"
printf 'VER="1.2.3"\ntouch "%s/executed"\n' "$TEST_TMP" > "$TEST_TMP/formulas/example.sh"
pin=$(ROOT=$TEST_TMP current '{"formula":"formulas/example.sh"}')
assert jq -en --argjson pin "$pin" '$pin == {pin:"1.2.3",version:[1,2,3,0]}' >/dev/null
assert test ! -e "$TEST_TMP/executed"
printf 'VER=$(touch "%s/executed")\n' "$TEST_TMP" > "$TEST_TMP/formulas/example.sh"
if ROOT=$TEST_TMP current '{"formula":"formulas/example.sh"}' 2>/dev/null; then echo 'FAIL: executable pin accepted'; exit 1; fi
assert test ! -e "$TEST_TMP/executed"
for scenario in failure clean unchanged create multiple; do
    (
        api() {
            if [[ ${3:-GET} != GET ]]; then printf '%s\n' "$3 $4" >> "$TEST_TMP/$scenario"; echo '{}'; return; fi
            case $scenario in
                create) echo '[]' ;;
                multiple) jq -cn --arg marker "$MARKER" '[{number:17,body:$marker},{number:18,body:$marker}]' ;;
                unchanged) jq -cn --arg body "$MARKER report" '[{number:17,body:$body}]' ;;
                *) jq -cn --arg marker "$MARKER" '[{number:17,body:$marker}]' ;;
            esac
        }
        case $scenario in
            failure) publish owner/project 'failure report' 0 1 ;;
            clean) publish owner/project 'clean report' 0 0 ;;
            unchanged) publish owner/project "$MARKER report" 1 0 ;;
            create) publish owner/project 'updates' 1 0 ;;
            multiple) if publish owner/project 'updates' 1 0 2>/dev/null; then exit 1; fi ;;
        esac
    )
done
assert grep -q '"body":"failure report"' "$TEST_TMP/failure"
assert grep -q '"state":"closed"' "$TEST_TMP/clean"
assert test ! -e "$TEST_TMP/unchanged"
assert grep -q '^POST ' "$TEST_TMP/create"
assert test ! -e "$TEST_TMP/multiple"
# Failed checks must produce a report and a failing exit status.
if (
    candidates() { echo 'HTTP 503 from mocked upstream' >&2; return 1; }
    GITHUB_STEP_SUMMARY="$TEST_TMP/summary" main --only OpenSSL
) > "$TEST_TMP/report"; then
    echo 'FAIL: failed upstream check returned success' >&2; exit 1
fi
assert grep -q 'HTTP 503 from mocked upstream' "$TEST_TMP/report"
assert grep -q '0 successful checks; 1 failed' "$TEST_TMP/report"
assert cmp -s "$TEST_TMP/report" "$TEST_TMP/summary"
if (main --only OpenSSL --file-issue) >/dev/null 2>&1; then
    echo 'FAIL: partial report allowed issue writes' >&2; exit 1
fi
# Only GitHub requests receive the GitHub token, and POST is never retried.
(
    curl() { printf '%s\n' "$@" > "$TEST_TMP/curl"; echo '{}'; }
    GH_TOKEN=test-token api projects/cairo/releases gitlab >/dev/null
)
if grep -q 'test-token' "$TEST_TMP/curl"; then echo 'FAIL: token leaked to GitLab'; exit 1; fi
(
    curl() { printf '%s\n' "$@" > "$TEST_TMP/curl"; echo '{}'; }
    GH_TOKEN=test-token api repos/owner/project/issues github POST '{"body":"test"}' >/dev/null
)
assert grep -q 'Authorization: Bearer test-token' "$TEST_TMP/curl"
if grep -q '^--retry$' "$TEST_TMP/curl"; then echo 'FAIL: POST retries enabled'; exit 1; fi
assert jq -Ren 'inputs | contains("| Library | Pinned | Latest stable upstream |\n| --- | --- | --- |")' --slurp < "$TEST_TMP/report" >/dev/null
printf '%s assertions passed\n' "$passed"
