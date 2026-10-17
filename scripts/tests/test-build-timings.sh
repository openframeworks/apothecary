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
echo 'Per-library build timing summaries passed'
