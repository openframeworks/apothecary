#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/ios/xcode"
sed '/^# Pins must match/,$d' "$root/apothecary/formulas/metalangle/metalangle/ios/xcode/fetchDependencies.sh" > "$fixture/ios/xcode/functions.sh"
source "$fixture/ios/xcode/functions.sh"
pin=645250b6690785be60ab6780ce4b58698d884d11
sleep() { :; }
git() {
    printf '%s\n' "$*" >> "$fixture/commands"
    if [ "$1" = init ]; then mkdir -p "$2"; return 0; fi
    local dir="$2" action="$3"
    case "$action" in
        remote) return 0 ;;
        fetch)
            local count=0
            if [ -f "$dir/count" ]; then count=$(cat "$dir/count"); fi
            count=$((count + 1)); printf '%s' "$count" > "$dir/count"
            case "$mode" in
                transient) [ "$count" -ge 2 ] ;;
                fallback) [ "$count" -ge 4 ] ;;
                permanent) return 1 ;;
                *) return 0 ;;
            esac ;;
        checkout) [ "$mode" != checkout-failure ] ;;
        rev-parse)
            if [ "$mode" = mismatch ]; then echo invalid; else echo "$pin"; fi ;;
        *) return 1 ;;
    esac
}
for mode in transient fallback permanent checkout-failure mismatch; do
    : > "$fixture/commands"
    if git_pull "$mode" "$pin" primary mirror; then
        case "$mode" in transient|fallback) ;; *) echo "Unexpected success: $mode" >&2; exit 1 ;; esac
    else
        case "$mode" in permanent|checkout-failure|mismatch) ;; *) exit 1 ;; esac
    fi
    case "$mode" in
        transient) [ "$(cat "$fixture/$mode/count")" = 2 ]; ! grep -q 'set-url origin mirror' "$fixture/commands" ;;
        fallback) [ "$(cat "$fixture/$mode/count")" = 4 ]; grep -q 'set-url origin mirror' "$fixture/commands" ;;
        permanent) [ "$(cat "$fixture/$mode/count")" = 6 ]; ! grep -q checkout "$fixture/commands" ;;
    esac
    ! grep -q 'fetch --depth=1 origin [^6]' "$fixture/commands"
done
echo 'MetalANGLE dependency retries, pinned mirror fallback and failure propagation passed'
