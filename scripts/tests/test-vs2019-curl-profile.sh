#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
for toolset in v142 v143; do
    (
        export TYPE=vs TARGET=vs ARCH=64 BUNDLE=2 VS_TOOLSET="$toolset"
        source "$root/scripts/calculate_formulas.sh"
        case " ${FORMULAS[*]} " in
            *' nghttp3 '*) [[ $toolset == v143 ]] ;;
            *) [[ $toolset == v142 ]] ;;
        esac
        case " ${FORMULAS[*]} " in
            *' ngtcp2 '*) [[ $toolset == v143 ]] ;;
            *) [[ $toolset == v142 ]] ;;
        esac
        source "$root/apothecary/formulas/curl/curl.sh"
        if [[ $toolset == v142 ]]; then
            [[ " ${FORMULA_DEPENDS[*]} " != *' nghttp3 '* && " ${FORMULA_DEPENDS[*]} " != *' ngtcp2 '* ]]
        else
            [[ " ${FORMULA_DEPENDS[*]} " == *' nghttp3 '* && " ${FORMULA_DEPENDS[*]} " == *' ngtcp2 '* ]]
        fi
        printf '#define USE_NGHTTP2 1\n#define USE_LIBSSH2 1\n' > "$fixture/config"
        if [[ $toolset == v143 ]]; then
            if (verify_required_features "$fixture/config"); then exit 1; fi
            printf '#define USE_NGTCP2 1\n#define USE_NGHTTP3 1\n' >> "$fixture/config"
        fi
        verify_required_features "$fixture/config"
        if [[ $toolset == v142 ]]; then
            printf '#define USE_NGTCP2 1\n' >> "$fixture/config"
            if (verify_required_features "$fixture/config"); then exit 1; fi
        fi
    )
done
echo 'VS2019 curl selection, dependency and generated-feature profiles passed'
