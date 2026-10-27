#!/usr/bin/env bash
# SDK/toolchain release tracking, separate from the vendor-library report.
set -euo pipefail
SDK_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$SDK_ROOT/scripts/check-upstream-versions.sh"
MARKER='<!-- apothecary-sdk-versions -->'
TITLE='Apothecary SDK version check'

sdk_toolchains() {
    python3 "$ROOT/scripts/check-sdk-toolchains.py" --root "$ROOT"
}

sdk_current() {
    local entry=$1 file variable raw pattern
    file=$(jq -r .file <<< "$entry")
    variable=$(jq -r .variable <<< "$entry")
    [[ $variable =~ ^[A-Za-z_][A-Za-z_0-9]*$ ]] || return 1
    case "$file" in /*|*../*) echo 'SDK pin must use a repository-relative file' >&2; return 1 ;; esac
    case $(jq -r .format <<< "$entry") in
        yaml_env)
            raw=$(awk -v key="$variable:" '$1 == key { print $2 }' "$ROOT/$file")
            raw=$(printf '%s' "$raw" | sed "s/^[\"']//; s/[\"'[:space:]#].*//")
            ;;
        *) echo 'Unsupported SDK pin format' >&2; return 1 ;;
    esac
    pattern=$(jq -r '.current_pattern // "(\\d+\\.\\d+\\.\\d+)"' <<< "$entry")
    json -en --arg pin "$raw" --arg pattern "$pattern" '
      include "upstream-versions";
      ($pin | version($pattern)) as $v |
      if $v == null then error("Unsupported or missing literal SDK version: " + $pin)
      else {pin: $pin, version: $v} end'
}

sdk_main() {
    local file_issue=0 repository=${GITHUB_REPOSITORY:-} registry entry name pin choices best
    local results='[]' errors='[]' tmp body updates failures toolchains successes
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file-issue) file_issue=1; shift ;;
            --repository) repository=${2:?Missing repository}; shift 2 ;;
            --help|-h) echo 'Usage: check-sdk-versions.sh [--file-issue --repository OWNER/REPO]'; return ;;
            *) echo "Unknown argument: $1" >&2; return 1 ;;
        esac
    done
    registry=$(cat "$ROOT/scripts/sdk-versions.json")
    jq -e 'type == "array" and length > 0 and
      (map(.name) | length == (unique | length)) and
      all(.[]; (.name | type == "string") and (.file | type == "string") and
        (.variable | type == "string") and (.repo | type == "string") and (.pattern | type == "string"))' <<< "$registry" >/dev/null
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" EXIT
    while IFS= read -r entry; do
        name=$(jq -r .name <<< "$entry")
        printf 'Checking SDK %s\n' "$name" >&2
        if pin=$(sdk_current "$entry" 2>"$tmp/error") && choices=$(candidates "$entry" 2>"$tmp/error"); then
            best=$(json -c --argjson entry "$entry" --argjson pin "$pin" --arg name "$name" '
              include "upstream-versions";
              max_by(.tag | stable_version($entry)) |
              . + {name:$name, pin:$pin.pin, newer:((.tag | stable_version($entry)) > $pin.version),
                   matching:((.tag | stable_version($entry)) == $pin.version), file:$entry.file, variable:$entry.variable}' <<< "$choices")
            results=$(jq -cn --argjson a "$results" --argjson b "$best" '$a + [$b]')
        else
            errors=$(jq -cn --argjson a "$errors" --arg name "$name" --rawfile error "$tmp/error" '$a + [{name:$name,error:($error | gsub("\\n"; " "))}]')
        fi
    done < <(jq -c '.[]' <<< "$registry")
    updates=$(jq '[.[] | select(.newer)] | length' <<< "$results")
    failures=$(jq length <<< "$errors")
    if ! toolchains=$(sdk_toolchains); then
        toolchains='{"markdown":"### Toolchain/action checks that failed\n\n- Collector failed; see action logs.\n","checks":0,"errors":1,"updates":0}'
    fi
    jq -e '.markdown | type == "string"' <<< "$toolchains" >/dev/null
    updates=$((updates + $(jq .updates <<< "$toolchains")))
    failures=$((failures + $(jq .errors <<< "$toolchains")))
    successes=$(($(jq length <<< "$results") + $(jq .checks <<< "$toolchains")))
    {
        printf '%s\n\n' "$MARKER"
        printf '%s\n\n' 'SDK/toolchain pins are compared with stable upstream releases. This report does not change SDK versions or establish compatibility.'
        printf '%s\n' '| SDK | Pinned | Latest stable upstream | Status | Pin source |' '| --- | --- | --- | --- | --- |'
        jq -r 'sort_by(.name | ascii_downcase)[] |
          "| \(.name) | \(.pin) | [\(.tag)](\(.url)) | \(if .newer then "Update available" elif .matching then "Up to date" else "Ahead of latest stable" end) | `\(.file)` (`\(.variable)`) |"' <<< "$results"
        if [[ $(jq length <<< "$results") -eq 0 ]]; then echo '| — | — | — | No successful checks | — |'; fi
        if [[ $failures -gt 0 ]]; then
            printf '\n### Checks that failed\n\n'
            jq -r '.[] | "- \(.name): \(.error)"' <<< "$errors"
        fi
        printf '\n'
        jq -r .markdown <<< "$toolchains"
        printf '\n%s successful checks; %s failed; %s updates available.\n' "$successes" "$failures" "$updates"
        printf '\nCoverage: Emscripten, Apple Xcode/bundled SDKs, Android SDK Build Tools/NDK, Microsoft Windows SDK/Visual Studio channels and external GitHub Action references.\n'
        printf '\nWorkflow: `.github/workflows/sdk-versions.yml`.\n'
    } > "$tmp/report"
    cat "$tmp/report"
    if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then cat "$tmp/report" >> "$GITHUB_STEP_SUMMARY"; fi
    body=$(cat "$tmp/report")
    if [[ $file_issue -eq 1 ]]; then publish "$repository" "$body" "$updates" "$failures" 1; fi
    [[ $failures -eq 0 ]]
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then sdk_main "$@"; fi
