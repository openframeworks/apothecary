# SDK Version check

The `SDK Version check` action runs weekly and supports manual dispatch. It
compares declared toolchain pins with upstream stable releases and maintains
its own **Apothecary SDK version check** issue, separate from the vendor-library
tracking issue. The SDK report stays open when all versions are current, so
there is always a table showing the pinned version, latest release, status and
pin location.

Emscripten's authoritative pin is the literal
`EMSDK_VERSION` in `.github/workflows/build-emscripten.yml`; upstream releases
come from the official `emscripten-core/emscripten` repository. Prereleases and
drafts are excluded. The checker reads literals without executing workflow
contents, and failed checks remain visible and fail the action.

The Emscripten registry is `scripts/sdk-versions.json`. The report also checks
Apple Xcode and bundled SDKs against Apple's Xcode support table, Android NDK and
SDK Build Tools matrix pins against Google's stable SDK repository, Windows SDK
defaults against Microsoft's download page, and selected Visual Studio major
versions against Microsoft's stable channel manifests. Apple deployment minimums
are not SDK versions. A VS major/runner label does not pin an installed compiler
patch; the report states that limitation.

External Action references are discovered by parsing workflows and local composite
actions with the same Ruby YAML dependency as the release planner. Stable GitHub
releases/tags are compared numerically, excluding previews. Floating major/minor
tags are identified as floating; commit-pinned forks and custom refs are shown for
manual review. Local/Docker Action references are excluded and counted.

Tests: `bash scripts/tests/test-sdk-versions.sh` and
`python3 scripts/tests/test-sdk-toolchains.py`. The collector uses Python 3.9+
standard-library HTTP/XML/HTML parsing and Ruby YAML; no pip dependencies are needed.

Run `bash scripts/check-sdk-versions.sh` for a read-only report. Issue writes
require `--file-issue --repository OWNER/REPO`. PR runs execute offline tests;
scheduled/manual upstream runs compare the actual `bleeding` pins. The checker
reports available versions and does not upgrade SDKs or establish build/runtime
compatibility.
