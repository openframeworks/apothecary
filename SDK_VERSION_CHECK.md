# SDK Version check

The `SDK Version check` action runs weekly and supports manual dispatch. It
compares declared toolchain pins with upstream stable releases and maintains
its own **Apothecary SDK version check** issue, separate from the vendor-library
tracking issue. The SDK report stays open when all versions are current, so
there is always a table showing the pinned version, latest release, status and
pin location.

Initial coverage is **Emscripten only**. Its authoritative pin is the literal
`EMSDK_VERSION` in `.github/workflows/build-emscripten.yml`; upstream releases
come from the official `emscripten-core/emscripten` repository. Prereleases and
drafts are excluded. The checker reads literals without executing workflow
contents, and failed checks remain visible and fail the action.

The SDK registry is `scripts/sdk-versions.json`. Android SDK/NDK, Apple SDKs and
other toolchains are not checked yet. New registry entries need a supported pin
reader and upstream stable-release source; do not mark an unchecked SDK current.

Run `bash scripts/check-sdk-versions.sh` for a read-only report. Issue writes
require `--file-issue --repository OWNER/REPO`. PR runs execute offline tests;
scheduled/manual upstream runs compare the actual `bleeding` pins. The checker
reports available versions and does not upgrade SDKs or establish build/runtime
compatibility.
