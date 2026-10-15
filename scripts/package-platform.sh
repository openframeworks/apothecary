#!/usr/bin/env bash
# Inspect literal platform declarations without executing formula scripts.
formula_has_package_for_target() {
    local library="$1" target="$2" root="$3" formula="" candidate declaration type
    case "$library" in pkg-config|automake) return 1 ;; esac
    case "$target" in macos) target=osx ;; esac
    for candidate in "$root/formulas/$library.sh" "$root/formulas/$library/$library.sh" "$root/formulas/_depends/$library.sh"; do
        if [ -f "$candidate" ]; then formula="$candidate"; break; fi
    done
    # Unknown explicitly requested libraries still reach the missing-output check.
    [ -n "$formula" ] || return 0
    grep -q '^FORMULA_TYPES=' "$formula" || return 0
    declaration=$(sed -n 's/^FORMULA_TYPES=(\([^)]*\)).*/\1/p' "$formula")
    if [[ ! "$declaration" =~ ^[A-Za-z0-9_\ \"\'\,\-]*$ ]]; then
        echo "Cannot inspect nonliteral FORMULA_TYPES for $library" >&2
        return 2
    fi
    declaration=$(printf '%s' "$declaration" | tr -d "\"',")
    for type in $declaration; do [ "$type" != "$target" ] || return 0; done
    return 1
}
