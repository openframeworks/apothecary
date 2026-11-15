#!/usr/bin/env bash
# Resolve Test libraries in openFrameworks dispatch/call inputs.
# Env: LIBRARY_REF, WORKFLOW_REF_TYPE, WORKFLOW_REF_NAME, PLATFORM
# Writes library_ref and platforms to GITHUB_OUTPUT when set, and always to stdout.
set -euo pipefail

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

library_ref="$(trim "${LIBRARY_REF:-}")"
case "$library_ref" in
    ''|auto)
        if [[ "${WORKFLOW_REF_TYPE:-}" == "tag" ]]; then
            library_ref="$(trim "${WORKFLOW_REF_NAME:?tag workflow is missing ref name}")"
        else
            library_ref="bleeding"
        fi
        ;;
esac
[[ -n "$library_ref" ]] || { echo "library_ref resolved empty" >&2; exit 2; }

platform="$(trim "${PLATFORM:?PLATFORM is required}")"
case "$platform" in
    linux|macos|ios|tvos|android|emscripten|windows)
        platforms="[\"${platform}\"]"
        ;;
    all)
        platforms='["linux","macos","ios","tvos","android","emscripten","windows"]'
        ;;
    *)
        echo "unsupported integration platform: $platform" >&2
        exit 2
        ;;
esac

{
    echo "library_ref=${library_ref}"
    echo "platforms=${platforms}"
} | tee -a "${GITHUB_OUTPUT:-/dev/null}"
