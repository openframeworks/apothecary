#!/usr/bin/env bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

retry_git() {
    local attempt
    for attempt in 1 2 3; do
        if git "$@"; then return 0; fi
        if [ "$attempt" -lt 3 ]; then sleep "$attempt"; fi
    done
    return 1
}

git_pull() {
    local dir="$1" rev="$2" url="$3" fallback="${4:-}" actual_rev
    cd "$SCRIPT_DIR/../.." || return 1
    echo "Fetching $url @ $rev ..."
    # Fetch the immutable pin instead of cloning the dependency's full history.
    # An interrupted fetch can be retried safely in the same repository.
    git init "$dir" || return 1
    if git -C "$dir" remote get-url origin >/dev/null 2>&1; then
        git -C "$dir" remote set-url origin "$url" || return 1
    else
        git -C "$dir" remote add origin "$url" || return 1
    fi
    if ! retry_git -C "$dir" fetch --depth=1 origin "$rev"; then
        if [ -z "$fallback" ]; then return 1; fi
        echo "Fetch failed; trying $fallback at the same commit"
        git -C "$dir" remote set-url origin "$fallback" || return 1
        retry_git -C "$dir" fetch --depth=1 origin "$rev" || return 1
    fi
    git -C "$dir" checkout --force "$rev" || return 1
    actual_rev=$(git -C "$dir" rev-parse HEAD) || return 1
    if [ "$actual_rev" != "$rev" ]; then
        echo "Dependency commit mismatch for $dir: expected $rev, got $actual_rev" >&2
        return 1
    fi
}

# Pins must match kakashidinho/metalangle @ ec92514 (2022 Metal backend).
# A newer SPIRV-Cross (e.g. 4d4b79bd) breaks mtl_glslang_utils.mm overrides.
glslang_revision="7d65f09b83112c1ec9e29313cb9913ed2b850aa0"
spirv_cross_revision="f38cbeb814c73510b85697adbe5e894f9eac978f"
jsoncpp_revision="48246a099549ab325c01f69f24a34fc72e5c42e4"
jsoncpp_src_revision="645250b6690785be60ab6780ce4b58698d884d11"

git_pull third_party/glslang/src ${glslang_revision} https://github.com/KhronosGroup/glslang.git
git_pull third_party/spirv-cross/src ${spirv_cross_revision} https://chromium.googlesource.com/external/github.com/KhronosGroup/SPIRV-Cross

# ✅ Public GitHub mirror (already fixed)
git_pull third_party/jsoncpp ${jsoncpp_revision} https://github.com/gsource-mirror/chromium-src-third_party-jsoncpp.git
git_pull third_party/jsoncpp/source ${jsoncpp_src_revision} https://chromium.googlesource.com/external/github.com/open-source-parsers/jsoncpp https://github.com/open-source-parsers/jsoncpp.git
