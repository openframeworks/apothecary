# Xcode 27.1 SDK test

The iOS, macOS and tvOS workflows use GitHub's `xcode-27` ARM64 preview runner,
which includes `/Applications/Xcode_27.1.app`. The SDK preflight rejects a
different Xcode or SDK version and reports the SDK's minimum deployment target
and supported architectures for device and simulator builds.

| Platform | Xcode 27.1 SDK | Apple-supported deployment floor | Apothecary target retained |
| --- | --- | --- | --- |
| macOS | 27.0 | 12.0 | 12.0 |
| iOS / iPadOS | 27.1 | 15.0 | 15.0 |
| tvOS | 27.0 | 15.0 | 18.0 |

SDK versions specify the headers and libraries used to compile. Deployment
targets specify the oldest OS the resulting program supports. Updating Xcode
does not require increasing these existing Apothecary targets. Keep macOS 12,
iOS 15 and tvOS 18 for this test; lowering tvOS to 15 should be reviewed and
validated independently. Xcode 27.1 itself requires macOS 26.6 or later on the
build host. The OS needed by Xcode is not an application deployment target.

The engine and shared Apple toolchain currently agree on these deployment
defaults. Library-specific availability and real-device runtime compatibility
still need validation; compiling with a new SDK does not establish those results.

Sources: [Apple system requirements](https://developer.apple.com/xcode/system-requirements),
[GitHub's Xcode 27 runner](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md).
