#!/usr/bin/env bash
set -euo pipefail
expected_xcode=${XCODE_VERSION:-27.1}
actual_xcode=$(xcodebuild -version | sed -n 's/^Xcode //p')
test "$actual_xcode" = "$expected_xcode" || {
    echo "Expected Xcode $expected_xcode; selected $actual_xcode (${DEVELOPER_DIR:-xcode-select default})" >&2
    exit 1
}
case "${1:-${TARGET:-}}" in
    osx|macos) sdks=(macosx:27.0) ;;
    ios) sdks=(iphoneos:27.1 iphonesimulator:27.1) ;;
    tvos) sdks=(appletvos:27.0 appletvsimulator:27.0) ;;
    *) echo 'Usage: check-apple-sdk.sh osx|ios|tvos' >&2; exit 1 ;;
esac
for entry in "${sdks[@]}"; do
    sdk=${entry%:*}
    expected=${entry#*:}
    actual=$(xcrun --sdk "$sdk" --show-sdk-version)
    test "$actual" = "$expected" || { echo "Expected $sdk $expected; selected $actual" >&2; exit 1; }
    sdk_path=$(xcrun --sdk "$sdk" --show-sdk-path)
    python3 - "$sdk_path/SDKSettings.plist" "$sdk" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    settings = plistlib.load(stream)
target = settings['SupportedTargets'][sys.argv[2]]
print(f"{sys.argv[2]} SDK {settings['Version']}: minimum deployment "
      f"{target['MinimumDeploymentTarget']}; architectures {', '.join(target['Archs'])}")
PY
done
