#!/usr/bin/env bash
# Per-formula timings for build.sh. Uses Bash's SECONDS for portable elapsed time.

APOTHECARY_BUILD_TIMINGS=()

apothecary_format_duration() {
    local total=${1:-0} hours minutes seconds
    hours=$((total / 3600))
    minutes=$(((total % 3600) / 60))
    seconds=$((total % 60))
    printf '%02d:%02d:%02d' "$hours" "$minutes" "$seconds"
}

apothecary_record_build_timing() {
    APOTHECARY_BUILD_TIMINGS+=("$1|$2|$3|$4")
}

apothecary_report_build_timings() {
    local target=${1:-unknown} arch=${2:-unknown} row library row_arch elapsed result report
    [ "${#APOTHECARY_BUILD_TIMINGS[@]}" -gt 0 ] || return 0

    report="### Library build timings — ${target} / ${arch}

Each duration covers the formula update, including cache checks, install and copy.

| Library | Architecture | Elapsed | Result |
|---|---|---:|---|"
    for row in "${APOTHECARY_BUILD_TIMINGS[@]}"; do
        IFS='|' read -r library row_arch elapsed result <<< "$row"
        report+=$'\n'"| ${library} | ${row_arch} | $(apothecary_format_duration "$elapsed") | ${result} |"
    done

    printf '\n%s\n' "$report"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
        printf '\n%s\n' "$report" >> "$GITHUB_STEP_SUMMARY"
    fi
}
