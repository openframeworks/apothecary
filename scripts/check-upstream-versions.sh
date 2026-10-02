#!/usr/bin/env bash
# Report stable upstream releases; maintain a tracking issue only with --file-issue.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MARKER='<!-- apothecary-upstream-versions -->'
TITLE='Apothecary libraries have newer upstream releases'

MODULE_DIR="$ROOT/scripts"
json() { jq -L "$MODULE_DIR" "$@"; }
api() {
    local path=$1 provider=${2:-github} method=${3:-GET} payload=${4:-}
    local host='https://api.github.com/'
    local args=(--fail --silent --show-error --connect-timeout 10 --max-time 30
        -H 'Accept: application/json' -H 'User-Agent: apothecary-upstream-versions')
    if [[ $provider == gitlab ]]; then
        host='https://gitlab.freedesktop.org/api/v4/'
    elif [[ -n ${GH_TOKEN:-${GITHUB_TOKEN:-}} ]]; then
        args+=(-H "Authorization: Bearer ${GH_TOKEN:-$GITHUB_TOKEN}")
    fi
    # Never retry POST: a lost response could otherwise create duplicate issues.
    if [[ $method == GET ]]; then args+=(--retry 2 --retry-delay 1); fi
    if [[ -n $payload ]]; then args+=(-H 'Content-Type: application/json' --data "$payload"); fi
    curl "${args[@]}" -X "$method" "$host$path" | jq -e .
}

current() {
    local entry=$1 variable formula raw pattern
    variable=$(jq -r '.variable // "VER"' <<< "$entry")
    formula=$(jq -r .formula <<< "$entry")
    [[ $variable =~ ^[A-Za-z_][A-Za-z_0-9]*$ ]] || return 1
    # Read a literal assignment, never source/eval the formula.
    raw=$(sed -n "s/^${variable}=//p" "$ROOT/$formula" | head -n 1)
    raw=$(printf '%s' "$raw" | sed "s/^[\"']//; s/[\"'[:space:]#].*//")
    pattern=$(jq -r '.current_pattern // "(\\d+(?:\\.\\d+)+)"' <<< "$entry")
    json -en --arg pin "$raw" --arg pattern "$pattern" '
      include "upstream-versions";
      ($pin | version($pattern)) as $v |
      if $v == null then error("Unsupported or missing literal pinned version: " + $pin)
      else {pin: $pin, version: $v} end'
}

candidates() {
    local entry=$1 provider repo prefix base batch rows all='[]' page endpoint url
    provider=$(jq -r '.provider // "github"' <<< "$entry")
    if [[ $provider == archive ]]; then
        url=$(jq -r .url <<< "$entry")
        batch=$(curl --fail --silent --show-error --retry 2 --connect-timeout 10 --max-time 30 --max-filesize 2000000 "$url") || return 1
        json -n --arg text "$batch" --argjson entry "$entry" 'include "upstream-versions"; $text | archive_rows($entry)'
        return
    fi
    repo=$(jq -r .repo <<< "$entry")
    prefix="repos/$repo"; base="https://github.com/$repo/tree/"
    if [[ $provider == gitlab ]]; then
        prefix="projects/$(jq -rn --arg repo "$repo" '$repo | @uri')"
        base="https://gitlab.freedesktop.org/$repo/-/tags/"
    fi
    for endpoint in releases tags; do
        all='[]'
        for ((page=1; page<=100; page++)); do
            url="$prefix/$endpoint"
            if [[ $provider == gitlab && $endpoint == tags ]]; then url="$prefix/repository/tags"; fi
            batch=$(api "$url?per_page=100&page=$page" "$provider") || return 1
            jq -e 'type == "array"' <<< "$batch" >/dev/null || return 1
            if [[ $endpoint == releases ]]; then
                rows=$(json --argjson entry "$entry" --arg base "$base" 'include "upstream-versions"; release_rows($entry; $base)' <<< "$batch") || return 1
            else
                rows=$(json --argjson entry "$entry" --arg base "$base" 'include "upstream-versions"; tag_rows($entry; $base)' <<< "$batch") || return 1
            fi
            all=$(jq -cn --argjson a "$all" --argjson b "$rows" '$a + $b')
            if [[ $(jq length <<< "$batch") -lt 100 ]]; then break; fi
        done
        if [[ $page -gt 100 ]]; then printf '%s\n' 'Pagination exceeded 100 pages' >&2; return 1; fi
        if [[ $(jq length <<< "$all") -gt 0 ]]; then printf '%s\n' "$all"; return; fi
    done
    printf '%s\n' 'No matching stable upstream release tags' >&2
    return 1
}

publish() {
    local repository=$1 body=$2 updates=$3 errors=$4 batch existing='[]' page=1 number old payload
    [[ $repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid owner/repository' >&2; return 1; }
    while :; do
        batch=$(api "repos/$repository/issues?state=open&per_page=100&page=$page") || return 1
        existing=$(jq -cn --argjson a "$existing" --argjson b "$batch" --arg marker "$MARKER" '$a + [$b[] | select(.pull_request == null and ((.body // "") | contains($marker)))]')
        [[ $(jq length <<< "$batch") -eq 100 ]] || break
        page=$((page + 1))
    done
    [[ $(jq length <<< "$existing") -le 1 ]] || { echo 'Multiple tracking issues found' >&2; return 1; }
    number=$(jq -r '.[0].number // empty' <<< "$existing")
    if [[ $updates -gt 0 || $errors -gt 0 ]]; then
        payload=$(jq -cn --arg body "$body" --arg title "$TITLE" '{body: $body, title: $title}')
        if [[ -n $number ]]; then
            old=$(jq -r '.[0].body' <<< "$existing")
            [[ $old != "$body" ]] || return 0
            api "repos/$repository/issues/$number" github PATCH "$payload" >/dev/null
        else
            api "repos/$repository/issues" github POST "$payload" >/dev/null
        fi
    elif [[ -n $number ]]; then
        api "repos/$repository/issues/$number" github PATCH '{"state":"closed"}' >/dev/null
    fi
}

main() {
    local file_issue=0 repository=${GITHUB_REPOSITORY:-} only='[]' entry name pin choices best
    local results='[]' errors='[]' skipped='[]' registry formulas configured tmp body updates failures
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file-issue) file_issue=1; shift ;;
            --repository) repository=${2:?Missing repository}; shift 2 ;;
            --only)
                shift
                [[ $# -gt 0 && $1 != --* ]] || { echo '--only needs library names' >&2; return 1; }
                while [[ $# -gt 0 && $1 != --* ]]; do
                    only=$(jq -cn --argjson names "$only" --arg name "$1" '$names + [$name]'); shift
                done ;;
            --help|-h) echo 'Usage: check-upstream-versions.sh [--only LIBRARY ...] [--file-issue --repository OWNER/REPO]'; return ;;
            *) echo "Unknown argument: $1" >&2; return 1 ;;
        esac
    done
    [[ $file_issue -eq 0 || $only == '[]' ]] || { echo '--only cannot maintain the full tracking issue' >&2; return 1; }
    registry=$(cat "$ROOT/scripts/upstream-versions.json")
    formulas=$(while IFS= read -r path; do
        if grep -q '^FORMULA_TYPES=' "$ROOT/$path"; then printf '%s\n' "$path"; fi
    done < <(git -C "$ROOT" ls-files 'apothecary/formulas/*.sh') | jq -Rsc 'split("\n") | map(select(length > 0)) | sort')
    configured=$(jq -c '[.[].formula] | sort' <<< "$registry")
    [[ $formulas == "$configured" ]] && jq -e 'map(.formula) | length == (unique | length)' <<< "$registry" >/dev/null || {
        echo 'Registry must cover each formula exactly once' >&2; return 1;
    }
    if [[ $only != '[]' ]]; then
        jq -en --argjson entries "$registry" --argjson names "$only" '$names - [$entries[].name] | length == 0' >/dev/null || { echo 'Unknown library in --only' >&2; return 1; }
        registry=$(jq -c --argjson names "$only" '[.[] | select(.name as $n | $names | index($n))]' <<< "$registry")
    fi
    tmp=$(mktemp -d)
    trap "rm -rf '$tmp'" EXIT
    while IFS= read -r entry; do
        name=$(jq -r .name <<< "$entry")
        if jq -e 'has("skip")' <<< "$entry" >/dev/null; then
            skipped=$(jq -cn --argjson a "$skipped" --argjson e "$entry" '$a + [$e]'); continue
        fi
        printf 'Checking %s\n' "$name" >&2
        if pin=$(current "$entry" 2>"$tmp/error") && choices=$(candidates "$entry" 2>"$tmp/error"); then
            best=$(json -c --argjson entry "$entry" --argjson pin "$pin" --arg name "$name" 'include "upstream-versions"; max_by(.tag | stable_version($entry)) | . + {name: $name, pin: $pin.pin, newer: ((.tag | stable_version($entry)) > $pin.version)}' <<< "$choices")
            results=$(jq -cn --argjson a "$results" --argjson b "$best" '$a + [$b]')
        else
            errors=$(jq -cn --argjson a "$errors" --arg name "$name" --rawfile error "$tmp/error" '$a + [{name: $name, error: ($error | gsub("\\n"; " "))}]')
        fi
    done < <(jq -c '.[]' <<< "$registry")
    updates=$(jq '[.[] | select(.newer)] | length' <<< "$results")
    failures=$(jq length <<< "$errors")
    {
        printf '%s\n\n' "$MARKER"
        printf '%s\n' 'A scheduled check compared formula pins with upstream stable releases.' 'A newer release may require a different supported branch, patches, checksums or platform changes.' 'This report does not change formulas.'
        printf '\n'
        printf '%s\n' '| Library | Pinned | Latest stable upstream |' '| --- | --- | --- |'
        jq -r '.[] | select(.newer) | "| \(.name) | \(.pin) | [\(.tag)](\(.url)) |"' <<< "$results"
        if [[ $updates -eq 0 ]]; then echo '| — | — | No newer releases detected among successful checks |'; fi
        if [[ $failures -gt 0 ]]; then
            printf '\n### Checks that failed\n\n'
            jq -r '.[] | "- \(.name): \(.error)"' <<< "$errors"
        fi
        printf '\n<details><summary>Coverage and exclusions</summary>\n\n%s successful checks; %s failed; %s explicitly excluded.\n\n' "$(jq length <<< "$results")" "$failures" "$(jq length <<< "$skipped")"
        jq -r '.[] | "- \(.name): \(.skip)"' <<< "$skipped"
        printf '\n</details>\n\nWorkflow: `.github/workflows/upstream-versions.yml`.\n'
    } > "$tmp/report"
    cat "$tmp/report"
    if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then cat "$tmp/report" >> "$GITHUB_STEP_SUMMARY"; fi
    body=$(cat "$tmp/report")
    if [[ $file_issue -eq 1 ]]; then publish "$repository" "$body" "$updates" "$failures"; fi
    [[ $failures -eq 0 ]]
}

# Functions may be sourced by the offline Bash regression tests.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
