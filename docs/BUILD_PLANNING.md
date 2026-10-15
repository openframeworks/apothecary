# Release-aware build planning

Active core workflows first run an Ubuntu pre-check. It fingerprints selected
formulas, their transitive FORMULA_DEPENDS and toolchain inputs before allocating
native runners. Linux modular builds select library × architecture rows, with
at most four builds in parallel. Disabled recipes (Boost and host pkg-config)
are not standalone Linux package producers. A fontconfig-only PR therefore does not build
macOS FreeImage or unrelated Linux modular libraries.

Desired matrices live in `scripts/build-matrices.json`. Edit Android SDK, NDK,
API and architecture axes there. EMSDK, Xcode and VS settings retain their existing
workflow environment locations. Both locations participate in invalidation.

Fingerprints include versions, BUILD_ID, source pins/checksums, recipes, patches,
configuration files, declared dependencies, architecture/bundle, toolchain and
installer scripts, compiler/ABI flags, deployment targets, engine, packaging and
metadata scripts. Do not hide dependencies in untracked downloads/environment
variables: declare them in FORMULA_DEPENDS and version the build settings.

## Published state

After trusted bleeding/master jobs publish successfully, each uploads a separate
`build-state-<workflow>-<job>-<variant-hash>.json` asset on the dedicated `build-state` prerelease. Filenames are prefixed with
`latest-`, `nightly-` or `modular-` to avoid branch/channel collisions. The
library archives remain on `latest`, `nightly` and `latest-modular`. Records contain:

- Formula versions, BUILD_ID, source pins and input SHA-256 fingerprints.
- Matrix/profile, source commit, run ID and publication time.
- Actual installed tool/SDK versions and runner image evidence.
- Verified archive filenames, asset IDs, sizes and SHA-256 digests.

JSON assets avoid concurrent writers overwriting a shared manifest or release
notes. Release notes remain editable prose. Removing/replacing recorded archives
invalidates reuse. Missing, malformed, expired or unavailable state triggers a
build. The first trusted publication bootstraps the state files.

PRs compare selected inputs with their base commit and do not publish or supply
trusted binaries. Unchanged PR platforms can skip even without release state,
because PR validation is not responsible for publishing missing release outputs.
Version tags always publish. Rolling latest/nightly tags, build-state and
nightly staging/backup tags do not trigger library builds. Manual dispatch forces the selected work to run. The Apple
XCFramework finalizer still runs for changes to other Apple platforms even when
iOS itself is skipped.

## Native reuse and rolling tools

Necessary jobs restore matching per-formula installed outputs through the platform
artifact action before compilation. Legacy Apple, Emscripten and VS jobs now use
this action instead of accepting arbitrary similarly named archive downloads.
Native cache keys include compiler/SDK context, runner image and package inventory
where available. Missing/expired artifacts cause source builds; publication still
runs after reuse.

Linux cannot discover exact tools on a future native runner without starting it.
Declared version changes invalidate immediately. State expires after **24 hours**
to force native rechecks of rolling images/tools. This bounds freshness; it is
not perfect toolchain discovery from Linux. Pin image digests, SDK/tool versions
and sysroot checksums for deterministic reuse. Native cache checks can still avoid
compilation when the recheck finds no changes.

Disabled watchOS/Linux-cross workflows and optional ANGLE/CUDA workflows retain
their existing policies. New standalone library workflows should adopt this
planner when merged, rather than duplicate release-state logic.

## Validation

Run `node scripts/tests/test-release-build-plan.cjs` plus the existing modular
cache, platform-artifact and scheduling tests. The new tests cover platform
isolation, dependencies, SDK matrices, archive identity/digests, expiry, tags and
API failure. Native compilation and publication still require CI and the first
trusted release upload; local planner tests do not establish those outcomes.
