# Optional modular build cache

`build-modular-optional.yml` publishes ANGLE separately to `latest-modular`.
MetalANGLE remains in the macOS/iOS/tvOS core formula lists and is also published
as an individual modular package. Each optional library/platform has its own job
and exact Actions cache, so changing one library does not rebuild another.

The cache contains `out/<library>` and, on Apple, `xout/<library>` with compiled
libraries, headers, metadata and staged XCFrameworks. It does not contain release
archives or source/build trees. A hit skips compilation and XCFramework staging;
packaging and release upload still run. Incomplete restored directories fail.

`scripts/modular-cache-key.sh LIBRARY` emits a SHA-256 key using:

- the selected formula tree and recursively declared dependency formula trees;
- shared engine, configuration, toolchains, installation and packaging scripts;
- platform, requested architectures, runner image and build flags;
- CMake/Ninja/compiler versions, Apple Xcode/SDKs, or Visual Studio installation.

Formula version, source commit, patches and build ID are covered by the formula
file hashes. Dependency declarations must be literal one-line arrays; formulas
are never executed to obtain the cache key. No partial restore keys are used.
Only successful build/package steps save outputs, before release upload, so an
upload failure can be retried without recompiling.

A missing, expired or evicted Actions cache causes a fresh build. Bump the formula
build ID to invalidate its cache explicitly. Adding another optional modular
library requires adding its workflow matrix entry; the existing key and build
scripts can be reused. PRs run offline tests and do not publish modular packages.

Run the offline checks with:

```bash
bash scripts/tests/test-modular-cache.sh
```

## Timing audit of PR #589 (2026-10-05)

The optional build jobs are skipped on `pull_request`; only their offline tests
run. The PR's Apple platform timings therefore measure the existing core artifact
reuse, setup and runner availability, not hits in the new optional cache.
The first optional publish may require a cold build after merging.

| Workflow/job | Time actually running | Main delay |
|---|---:|---|
| iOS bundle 1 | 20 minutes | 5.4 minutes setup, 13.4 minutes build steps |
| iOS bundles 2 / 3 | 6.8 minutes each | 4.5–5.7 minutes setup; cached build steps take seconds |
| tvOS bundle 1 | 236 minutes | 212 minutes Homebrew setup; 23 minutes build steps |
| tvOS bundles 2 / 3 | 152 / 196 minutes | 150 / 194 minutes Homebrew setup |

The iOS bundle 2 job started nine hours after workflow creation. Its later
`wait-for-workflows` job spent another 85 minutes waiting for macOS and failed
with `Server Error`, even though macOS had already completed. That wait now runs
only for release pushes, matching the XCFramework release job that consumes it.
See the [iOS run](https://github.com/openframeworks/apothecary/actions/runs/37254201329)
and [tvOS run](https://github.com/openframeworks/apothecary/actions/runs/37254201183).

The tvOS log shows Homebrew upgrading CMake and compiling ccache's LLVM/Rust
prerequisites from source. Apple setup now preserves installed runner tools,
skips automatic Homebrew updates/upgrades in CI, and installs only missing
required formulae. Optional ccache, gtk-doc and wget2 installations remain
available locally; CI can use any already installed copies. This reduces setup
work before artifact restore, but missing required tools can still require
installation and new runner images can change the toolchain fingerprint.

Each optional build now writes its exact cache key and hit/miss to the job
summary. The shared Apple installer is included in the key. The `tvOS` directory
is matched case-insensitively when fingerprinting the `tvos` installer.

Further improvements should be separate, measured changes:

- Core artifact lookup currently considers only one repository artifact page and
  matches names by substring without deduplicating bundle names. It worked for
  this iOS run, but needs paginated, exact-name selection to avoid missing bundles
  or overwriting a newer archive with an older duplicate.
- Core binary reuse validates formula version/build ID rather than the complete
  formula/dependency/toolchain fingerprint used by optional outputs. Extending
  exact caching to core libraries needs dependency-aware invalidation and
  retained PR validation of the changed formulas.
- Queue time needs runner capacity or fewer redundant jobs; a binary cache cannot
  remove time before a runner starts. Consider workflow concurrency/cancellation
  and change-aware platform selection without skipping required validation.
- Compiler caching requires persistent storage and actual compiler launcher
  integration. Installing ccache alone does not provide cross-run reuse.
