# Changelog

Curated from the git history of [openframeworks/apothecary](https://github.com/openframeworks/apothecary) (2,417 commits, 258 PR merges, June 2013 – August 2026). Not every commit is listed — this pulls out the merges that changed platform support, bumped a library version, or reshaped the build/CI system. PR numbers link to `github.com/openframeworks/apothecary/pull/<n>`.

## Release tags (openFrameworks library bundles)

| Tag | Date | Notes |
|---|---|---|
| `latest` / `latest-modular` | rolling, last moved 2026-08-10 | Auto-updated to the newest bleeding build |
| `v12.1.1` | 2026-04-05 | |
| `v12.1.0` | 2025-07-21 | |
| `v12.0.0` | 2023-12-01 | |
| `nightly` | 2022-05-09 | First CI-published nightly stream |

`bleeding` (rolling, latest-commit build) isn't a fixed tag but is referenced throughout CI/README as the always-current stream.

## 2026 (Jan – Aug, 23 merges)

- **VS2026** support added (#546), then FreeImage link-error fixes for it (#556) and VS2022 runner fixes (#559)
- **Emscripten** bumped 4.0.16 → 5.0.5 → 5.0.6 → 5.0.7 → 6.0.6 (#547, #553, #557, #566)
- **FreeImage** 3.19.10 → 3.19.11 (#551), then 3.19.12, 3.19.13, 3.19.14, then 3.19.15 (ICO/PSD heap-overflow CVEs)
- **Linux "generic" distro / GCC10** support added — release path fixes (#567, #568, #569)
- **Apo Menu** interactive CLI with a configurable output folder for deploying straight into an OF checkout (#563, #564)
- **pixman** 0.46 link errors fixed (missing region64f / riscv sources) (#560)
- **tess2** Apple-silicon `TARGET_OS_*` macro fixes (#558, #561)
- msys2 build fixes for assimp, kiss, tess2 (#555)
- LibPNG / Brotli(zlib) dependency updates (#550)
- GitHub Actions release tooling rebuilt: auto-tagging `latest` on every successful run, release workflow 2.6.1 → 3.0.1 (#565, #570, #548)

## 2025 (56 merges)

- **Android**: NDK bumped to 28 then 28.2, SDK 36, x86_64 emulator fixes, OpenCV rebuilt for the new NDK (#521, #543, #490)
- **Linux**: new cross-compile toolchains, Wayland/X11 auto-detection, RPi cross-build fixes — a long chain of PRs rebuilding the Linux pipeline (#468–#498, #499, #500)
- **cURL / OpenSSL**: version updates plus macOS, VS, and Android path fixes (#538, #541, #542, #529)
- **OpenCV** 4.11.0, with Assimp switched to static builds and VS/emscripten fixes (#494, #495, #519, #520)
- **MetalANGLE** toggled off pending further work (#535) after being introduced in 2024
- **FreeType** moved to modern CMake targets (#501); **FreeImage** got explicit C/C++ standard + Unicode CMake packaging (#527)
- Auto-retry added for failed release jobs (#532)
- `v12.1.0` openFrameworks libraries tagged 2025-07-21

## 2024 (84 merges — the busiest year in the repo)

- **XCFrameworks**: apothecary's Apple-platform output was rebuilt end-to-end around `.xcframework` bundles (iOS/tvOS/watchOS/visionOS/catOS/macOS), with header bundling and packaging fixed across a long PR chain (#337, #339, #353, #361, #368, #380, #381, #383, #385, #411–#418)
- **MetalANGLE** introduced — OpenGL-over-Metal via ANGLE (#442)
- **Vulkan** system + shader formula support added (#446)
- **C17 / C++23** standard variables introduced across formulas (#390)
- **VS2022** LLVM/Clang host-compiler toolchain support (#340)
- **Emscripten** 3.1.42 → 3.1.73, with a pthreads on/off matrix and WebAssembly updates (#364, #395, #396, #458)
- **json (nlohmann)** formula added, then updated repeatedly (#350, #429, #430, #432, #443)
- **fmt** formula added (#350)
- **cURL** 8.8.0 → 8.9.1 (#412)
- CI artifact caching reworked with build-versioning via `.pkl` files, cutting redundant rebuilds (#376, #384, #387, #421)

## 2023 (15 merges)

- **Linux aarch64** support added (#233, #270, #277, #278)
- CI runners moved to Ubuntu Latest (#268)
- `nlohmann::json` updated (#267); `glm` bumped (#272)
- Emscripten pthread support (#262)
- assimp 5.3.1 (fixes glTF loading under emscripten) (#296)
- `v12.0.0` openFrameworks libraries tagged 2023-12-01

## 2022 (28 merges)

- **GitHub Actions** CI introduced for Windows (#210), then nightly builds published straight to GitHub Releases (#218, #219, #222) — replacing the old Travis/AppVeyor-only pipeline
- Git remotes switched from `git://` to `https://` repo-wide (#217)
- assimp 5.2.5 with FBX support (#236); OpenCV 4.6 (#235); glfw 3.3.7 → 3.3.8 (#225, #234)
- MSYS2 CI flavours added, pkg-config-based linking (#226, #228)
- utfcpp v2.3.4 → v3.2.1, moved to GitHub/https (#211)

## 2021 (23 merges)

- Apple Silicon / M1 compatibility fixes across several libraries (#174), following up on early Apple Silicon support requests
- fmod formula added for newer FMOD builds, incl. msys2 64-bit (#168, #188)
- glfw pinned back to 3.3 stable (#187); glm 0.9.9.7 (#182)
- OpenCV arm64 fixes (#193, #196)

## 2020 (8 merges, mostly December)

- **GitHub Actions support added** — the first Actions-based CI in the repo (#170), followed by upload/publish fixes (#171–#175)
- MSYS2 svgtiny fix (#169); Windows CI moved to a VS2019 build image (#166)

## 2019 (16 merges)

- **Android arm64** support added, NDK bumped to API 21 (#134, #135)
- **MSYS2 Mingw64** support (#150, #151, #155)
- OpenCV updated to 4.0 / 4.0.1 (#124, #126, #140)
- `nlohmann::json` introduced as a formula (#128, #130)
- pugixml 1.9 (#131)

## 2018 (5 merges)

- FreeImage updated to 3.18, dropping the VS2013 redistributable requirement (#118)
- Library set updated for VS2017 (#106)
- rtAudio and cairo Windows build fixes (#104, #105)

## 2013 – 2017 (pre-PR-numbered era)

GitHub PR merges weren't consistently numbered in commit messages yet, so this era is summarized rather than itemized:

- **June 2013** — initial commit: the core Bash build engine, the formula abstraction (download/prepare/build/copy/clean), and the first formulas (kiss, poco, tess2, cairo, glfw)
- **2013** — git-mode (`-g`) added for pulling formulas from git instead of tarballs; addon formula support (`addons/ofxAddonName/scripts/formulas`) added; `osx-clang-libc++` build flavor added
- **2014** — continued formula hardening and OSX/iOS fat-lib packaging fixes
- **2016–2017** — the two heaviest pre-PR years by raw commit count (480 and 153 commits respectively); largely formula updates, Windows/VS build-type expansion, and Travis/AppVeyor CI upkeep

---

*Method: `git log --pretty='%ad|%h|%s' | grep -E '\(#[0-9]+\)'` against the full unshallowed history, cross-referenced with `git for-each-ref` for tag dates. Generated 2026-08-11 — regenerate the same way for anything merged after this date.*
