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
