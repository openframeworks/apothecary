# Working on Apothecary

Apothecary builds and packages openFrameworks dependencies across several
platforms. Read [scripts/AGENTS.md](scripts/AGENTS.md) before driving the `apo`
CLI. Formula pins and compatibility policy are documented in
[FORMULA_VERSION_MATRIX.md](FORMULA_VERSION_MATRIX.md); check the actual formula
and current upstream release before changing a pin, since the matrix is a dated
snapshot.

## Repository map

- `apothecary/apothecary`: formula execution, toolchain setup, archive handling.
- `apothecary/formulas/`: source pins, patches and download/build/copy functions.
- `scripts/calculate_formulas.sh`: platform selections, modular-only and internal
  libraries. Check the selected list as well as a formula's `FORMULA_TYPES`.
- `scripts/build.sh`, `scripts/package.sh`, `scripts/package-individual.sh`:
  compilation, core archives and individual library packages.
- `.github/workflows/`: runner images, SDK/compiler setup, caches and publishing.
- `scripts/secure.sh`: metadata for installed binaries; source verification is
  separate from this metadata.

## Formula changes

1. Verify archive SHA-256 values against the exact download URL before extracting.
   Main and contrib archives can share a filename but have different hashes.
   For Git sources, pin and verify the full 40-character commit. Do not remove
   verification to work around a mismatch. Run the formula checksum audit.
2. Inspect upstream build options and generated configuration headers. Successful
   compilation does not establish that the requested features work at runtime.
   For OpenSSL, test random generation, context creation and certificate
   verification through direct OpenSSL users as well as curl; an Apple curl
   backend may use system certificate verification and conceal an OpenSSL issue.
3. Apply patches in `prepare()` with a repeatable guard and propagate failures.
   Scope platform fixes to the affected builds. Preserve working fallbacks when
   a vendored acceleration backend cannot compile, and document any feature or
   performance tradeoff.
4. Increment the formula's `BUILD_ID` when patches, flags or packaged outputs
   change without a version change, so previously cached builds are invalidated.
5. Trace the complete download → prepare → build → install → copy → package path.
   Do not stop after a successful compiler invocation.

## Platform and archive pitfalls

- ARM64EC can define `_M_X64`. That macro alone is insufficient to select x86
  intrinsics: exclude `_M_ARM64EC` from explicit AVX kernels, headers and callers,
  and keep the scalar path. Disabling CMake intrinsics does not necessarily
  disable hand-written AVX code in individual source files.
- Read the actual CMake install output before validating or renaming libraries.
  OpenCV versions and generators can differ in suffixes and archive extensions.
  MSVC COFF archives may be emitted with `.a` names; renaming for packaging must
  preserve bytes, Debug suffixes and third-party libraries. MSYS2 does not
  necessarily use the same version suffix as MSVC. Validate the path passed to
  `secure()` against the files actually copied.
- MSVC dependency discovery can accidentally select MinGW headers through PATH
  or CMake search paths. Check the compiler's include paths and detected package
  locations before adding another dependency or disabling a whole module.
- Static archives can contain multiple members with the same basename. `ar x`
  into one directory overwrites those members. Preserve duplicate members when
  re-indexing (the engine uses `ar s` in place for these archives). Compare
  `ar t` member counts and duplicates, and check `nm` for defined symbols rather
  than merely matching names that may occur only as undefined references.
- Apple deployment defaults appear in the engine, toolchains, formulas and CI.
  Check all relevant layers and device/simulator targets when changing minimums.
  Distinguish the SDK/Xcode version from the deployment target; preserve explicit
  caller overrides. Verify support against the selected runner image and SDK.

## Core, modular packages and caches

Keep core selection, modular selection and internal dependencies consistent with
both packaging scripts. Building a library does not automatically mean it
belongs in the core archive. Keep Google ANGLE and the frozen MetalANGLE fork
separate: they have different source pins, build systems and platform support.
Check the branch's platform lists before changing either backend's defaults.

For artifact caching, include the selected formula and its dependencies, patches,
build and packaging scripts, flags, architecture, compiler and SDK in the key.
Avoid relying solely on a version string or broad restore key. A cache hit must
contain the complete installed/staged output required for packaging. Reuse may
skip compilation, but packaging still needs to run for the current release.
Account for cache eviction and test both invalidation and reuse. Cache workflow
or helper changes from an unmerged PR must not be assumed present on `bleeding`.

## Validation and PR workflow

- Run `bash -n` on changed shell scripts and `git diff --check`. For formula
  changes, run `bash scripts/audit-formula-checksums.sh`. Keep shared shell code
  compatible with the supported runner shells, including macOS Bash 3.2 where
  scripts use it. Parse changed workflow YAML and check runner/tool versions.
- Use a focused reproduction for the failure: duplicate archive members with
  distinct symbols, real copy functions with representative install filenames,
  or preprocessing with ARM64EC macros. State when a native toolchain was not
  available; local shell checks do not establish a Windows build result.
- Diagnose CI for the current PR head SHA. Find the first meaningful compiler,
  linker or packaging error, not just the final failure line. Separate failures
  by architecture/toolchain and distinguish warnings from fatal errors.
- Work on a dedicated branch from current `bleeding`. Before rebasing, check the
  worktree and remote head. Preserve newer upstream changes when resolving
  conflicts; use an exact `--force-with-lease` when pushing rewritten history.
  Keep unrelated PR fixes separate, and do not commit build output or credentials.
- Report the pushed commit and distinguish local checks, queued/running CI and
  completed CI. A library fix is not verified downstream until the produced
  artifact is checked and its consumer builds successfully. When publishing is
  triggered by the merge, wait for that publication before rerunning consumers.
- PR descriptions should explain the concrete failure, resulting behavior and
  validation limits. Do not add AI attribution or generated-by trailers.
