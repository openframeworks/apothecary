#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source "$ROOT/scripts/build-timings.sh"

[[ "$(apothecary_format_duration 65)" == "00:01:05" ]]
[[ "$(apothecary_format_duration 3661)" == "01:01:01" ]]
summary=$(mktemp)
trap 'rm -f "$summary"' EXIT
GITHUB_STEP_SUMMARY=$summary
APOTHECARY_BUILD_TIMINGS=()
apothecary_record_build_timing pixman arm64 65 completed
apothecary_record_build_timing zlib arm64 3661 completed
output=$(apothecary_report_build_timings macos arm64)
[[ "$output" == *'Library build timings — macos / arm64'* ]]
[[ "$output" == *'| pixman | arm64 | 00:01:05 | completed |'* ]]
[[ "$output" == *'| zlib | arm64 | 01:01:01 | completed |'* ]]
printf '%s\n' "$output" | cmp -s "$summary" -

APOTHECARY_BUILD_TIMINGS=()
[[ -z "$(apothecary_report_build_timings macos arm64)" ]]

# Modular workflows invoke build.sh once per library; defer each process's
# report and combine all successful and failed rows into one final table.
timings_file=$(mktemp)
trap 'rm -f "$summary" "$timings_file"' EXIT
: > "$summary"
APOTHECARY_BUILD_TIMINGS=()
APOTHECARY_BUILD_TIMINGS_FILE=$timings_file
APOTHECARY_BUILD_TIMINGS_DEFER=1
apothecary_record_build_timing dawn 64 13 failed
[[ -z "$(apothecary_report_build_timings linux 64)" ]]
APOTHECARY_BUILD_TIMINGS=()
apothecary_record_build_timing pixman 64 65 completed
[[ -z "$(apothecary_report_build_timings linux 64)" ]]
APOTHECARY_BUILD_TIMINGS_FILE=
APOTHECARY_BUILD_TIMINGS_DEFER=0
output=$(apothecary_report_build_timings_file linux 64 "$timings_file")
[[ "$output" == *'| pixman | 64 | 00:01:05 | completed |'* ]]
[[ "$output" == *'| dawn | 64 | 00:00:13 | failed |'* ]]
[[ "$(grep -c '^| Library |' "$summary")" -eq 1 ]]
[[ "$(grep -c '^| dawn |' "$summary")" -eq 1 ]]
[[ "$(grep -c '^| pixman |' "$summary")" -eq 1 ]]
echo 'Build timing summaries aggregate all libraries into one table'
