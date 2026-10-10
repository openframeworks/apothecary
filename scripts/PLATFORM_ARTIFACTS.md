# Core platform artifact reuse

Android, MSYS2, Catalyst (`catos`) and visionOS (`xros`) use the shared
`.github/actions/platform-artifacts` action. Successful `bleeding` and `master`
push builds provide trusted baselines. PRs restore from their base branch;
tag builds compile from source and retain their release packaging/upload steps.
Fork PRs can read the base repository's artifacts with the read-only Actions
token. PRs cannot publish a baseline.

Artifact names include the platform and matrix architecture/flavor or Apple
bundle: `platform-v1-<target>-<variant>`. Lookup paginates successful push runs
of that platform workflow, matches exact artifact names, and rejects expired
artifacts. The newest available baseline contains the complete raw `out/`
tree, including metadata and curl's internal transport dependencies. Tar
preserves executable permissions and symlinks. Apple jobs restore all their
architectures together; XCFramework staging and release packaging still run.

Each formula has a fingerprint covering its own source/patch tree, recursively
declared dependencies, engine/toolchain/build/packaging helpers, platform workflow,
architecture set, bundle, flags, runner image and actual build tools. Android
also covers the pinned NDK, NDK compiler, SDK and minimum API. MSYS2 covers its
flavor and installed package versions; Apple covers Xcode/SDKs and Homebrew
package versions. Toolchain reports are collected once per job. A changed
dependency invalidates its consumers; an unrelated formula does not. Old
artifacts without fingerprints cannot be accepted.

Only matching formula directories are restored, with an atomic directory rename
after copying. The existing engine then checks version/build metadata for each
architecture and checks that declared dependencies exist. A missing/expired
artifact or lookup/download/fingerprint failure falls back to source builds.
Restore/upload failures do not prevent release packaging; a failed restore
cannot publish a baseline with an incomplete input manifest.

The first successful branch push after merge seeds the new artifact format.
Artifacts expire after 30 days; runner/toolchain updates intentionally invalidate
them. This change does not migrate the other platforms' existing artifact
implementations or make `latest-modular` a universal fallback (see issue #619).
MSYS2 also re-enables its setup action's package-download cache; rolling package
updates remain enabled and are reflected in the binary fingerprints.

## Scheduling

The 15 previously unrestricted platform push triggers now run for `bleeding`,
`master` and tags. Feature branches validate through PR events, avoiding a
second push build for same-repository PRs. The existing branch-only modular
triggers keep their branch policy. Manual dispatch remains available where it
already existed.

All 18 existing build concurrency groups use workflow name plus PR number or
branch ref. New runs cancel superseded runs within that workflow and PR/branch;
different workflows/PRs/branches stay independent. Tags use unique run IDs and
disable cancellation, preserving every tagged publication rather than replacing
pending tag runs. This affects newly scheduled runs; old push runs using their
unique legacy groups need separate cancellation.

Offline checks:

```bash
bash scripts/tests/test-modular-cache.sh
node scripts/tests/test-platform-artifacts.cjs
ruby scripts/tests/test-workflow-scheduling.rb
```

Native CI and a subsequent warm branch/PR run are still needed to establish
actual cache hit counts and time saved. Binary reuse reduces build time, not
time waiting for runners.
