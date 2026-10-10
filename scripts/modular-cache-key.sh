#!/usr/bin/env bash
# Exact cache key for one modular library and its compiled dependencies.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
LIBRARY=${1:?Usage: modular-cache-key.sh LIBRARY}
: "${TARGET:?TARGET is required}"
: "${OPTIONAL_ARCHS:=${ARCH:-64}}"

seen=' '
formula_paths=()
collect_formula() {
    local lib=$1 formula depends dependency
    [[ $lib =~ ^[A-Za-z0-9_-]+$ ]] || { echo "Invalid formula: $lib" >&2; return 1; }
    [[ $seen != *" $lib "* ]] || return 0
    seen="$seen$lib "
    formula=$(git ls-files "apothecary/formulas/$lib.sh" "apothecary/formulas/$lib/$lib.sh" "apothecary/formulas/_depends/$lib.sh")
    [[ -n $formula && $formula != *$'\n'* ]] || { echo "Cannot identify formula: $lib" >&2; return 1; }
    if [[ $(dirname "$formula") == apothecary/formulas || $(dirname "$formula") == apothecary/formulas/_depends ]]; then
        formula_paths+=("$formula")
    else
        formula_paths+=("$(dirname "$formula")")
    fi
    # Never source formulas. Only accept a literal one-line dependency list.
    # Legacy formulas (e.g. pkg-config and rtAudio) use the engine's empty default.
    if ! grep -Eq '^[[:space:]]*FORMULA_DEPENDS[+]?=' "$formula"; then
        return 0
    fi
    [[ $(grep -Ec '^FORMULA_DEPENDS=\(.*\)' "$formula") == 1 ]] || { echo "Expected literal dependency list: $lib" >&2; return 1; }
    depends=$(sed -n 's/^FORMULA_DEPENDS=(\(.*\)).*/\1/p' "$formula")
    [[ $depends =~ ^[A-Za-z0-9_\ \"\'\-]*$ ]] || { echo "Nonliteral dependencies: $lib" >&2; return 1; }
    depends=$(printf '%s' "$depends" | tr -d "\"'")
    for dependency in $depends; do collect_formula "$dependency"; done
}
collect_formula "$LIBRARY"
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT
{
    printf 'modular-cache-v1\n%s\n%s\n%s\n' "$LIBRARY" "$TARGET" "$OPTIONAL_ARCHS"
    printf '%s\n' "${RUNNER_OS:-$(uname -s)}" "${RUNNER_ARCH:-$(uname -m)}" "${ImageVersion:-}"
    if [[ -n ${PLATFORM_ARTIFACT_CONTEXT:-} ]]; then
        cat "$PLATFORM_ARTIFACT_CONTEXT"
    fi
    # Include all caller build settings, excluding credentials and job metadata.
    env | LC_ALL=C sort | sed -En '/^(OPENCV_.*|ANGLE_.*|CPP_STANDARD|C_STANDARD|CFLAGS|CXXFLAGS|CPPFLAGS|LDFLAGS|FLAGS_.*|FLAG_.*|VS_VER|MULTITHREADED_TYPE|PTHREADS_ENABLED|DEVELOPER_DIR|SDKROOT|.*DEPLOYMENT_TARGET)=/p'
    if [[ -z ${PLATFORM_ARTIFACT_CONTEXT:-} ]]; then bash scripts/cache-toolchain.sh; fi
    # Shared build/packaging infrastructure and the selected formula trees.
    while IFS= read -r path; do
        printf '%s %s\n' "$path" "$(git hash-object "$path")"
    done < <(git ls-files -- apothecary/apothecary apothecary/configure apothecary/toolchains \
        scripts/apo.sh scripts/build-modular-optional.sh scripts/modular-cache-key.sh scripts/cache-toolchain.sh \
        scripts/calculate_formulas.sh scripts/apple-install-tools.sh scripts/load.sh scripts/save.sh scripts/secure.sh \
        scripts/package-individual.sh scripts/export_config.sh ":(icase)scripts/$TARGET/install.sh" apo "${formula_paths[@]}" | LC_ALL=C sort -u)
    if [[ -n ${PLATFORM_ARTIFACT_CONTEXT:-} ]]; then
        while IFS= read -r path; do
            printf '%s %s\n' "$path" "$(git hash-object "$path")"
        done < <(git ls-files -- scripts/build.sh scripts/package.sh scripts/artifact \
            scripts/platform-artifact-manifest.sh scripts/platform-artifacts.cjs \
            .github/actions/platform-artifacts ".github/workflows/build-$TARGET.yml" \
            ":(icase)scripts/$TARGET" | LC_ALL=C sort -u)
    fi
} > "$manifest"
if command -v shasum >/dev/null; then
    digest=$(shasum -a 256 "$manifest" | cut -d ' ' -f1)
else
    digest=$(sha256sum "$manifest" | cut -d ' ' -f1)
fi
printf 'key=modular-v1-%s-%s-%s\n' "$TARGET" "$LIBRARY" "$digest"
