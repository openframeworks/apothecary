apothecary of openFrameworks https://github.com/openframeworks/openframeworks/
==========

[![build-vs2022-64](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-x64.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-x64.yml)
[![build-macos](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml)
[![build-ios](https://github.com/openframeworks/apothecary/actions/workflows/build-ios.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-ios.yml)
[![build-android](https://github.com/openframeworks/apothecary/actions/workflows/build-android.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-android.yml)
[![build-emscripten](https://github.com/openframeworks/apothecary/actions/workflows/build-emscripten.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-emscripten.yml)

apothecary is the [openFrameworks](http://openframeworks.cc) library apothecary — a Bash/CMake/Make build system that downloads, builds, and packages the C/C++ library dependencies ("potions") openFrameworks needs, on every platform it supports.

Each library has its own formula script that abstracts the download, prepare, build, copy, and clean steps, inspired by [Homebrew](https://brew.sh). The main `apothecary` engine reads a formula, runs the right steps for your target platform/architecture, and drops the result in the right place. This means library binaries don't need to live in the OF core repo — anyone building from git just runs apothecary once to produce them.

```
./apo update core
```

or, using the underlying engine directly:

```
./apothecary/apothecary -t ios -a arm64 update core
```

## Libraries

Core OF formulas currently in `apothecary/formulas`, with the version each currently pins:

angle, assimp, boost, brotli, cairo, curl, dawn, fmod, fmodex, fmt, FreeImage, freetype, glew, glon12, glfw, glm, gstreamer, json, kiss, libpng, libssh2, libusb, libxml2, metalangle, opencv, openssl, pixman, poco, portaudio, pugixml, rtAudio, shaderc, svgtiny, tess2, uriparser, utf8, videoInput, zlib

Run `./apo formulas` (or `apothecary/apothecary -h`) to list what's available in your checkout — this list (and the versions) changes as formulas are updated.

## Automation

Libraries are built on [GitHub Actions](https://github.com/openframeworks/apothecary/actions) and published with `.pkg` hashes alongside each release.

* **Bleeding (latest openFrameworks):** [releases/tag/bleeding](https://github.com/openframeworks/apothecary/releases/tag/bleeding) — fetched in openFrameworks via `scripts/<platform>/download_latest_libs.sh`
* **Nightly (stable openFrameworks 0.12):** [releases/tag/nightly](https://github.com/openframeworks/apothecary/releases/tag/nightly) — fetched in openFrameworks via `scripts/<platform>/download_libs.sh`

## Build status

| Platform                      | Status | Info | Extra Info |
|--------------------------------|--------|------|------------|
| **Windows x86_64 (VS2022)**    | [![build-vs2022-64](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-x64.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-x64.yml) | VS2022 | C++2b, C17 |
| **Windows x86_64 (VS2026)**    | [![build-vs2026-64](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2026-x64.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2026-x64.yml) | VS2026 | C++2b, C17 |
| **Windows arm64**              | [![build-vs2022-arm64](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022_arm64.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022_arm64.yml) | VS2022 | C++2b, C17 |
| **Windows arm64EC**            | [![build-vs2022-arm64ec](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-arm64ec.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-vs2022-arm64ec.yml) | VS2022 | C++2b, C17 |
| **Windows (MSYS2)**            | [![build-msys2](https://github.com/openframeworks/apothecary/actions/workflows/build-msys2.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-msys2.yml) | MINGW32/64 | C++2b, C17 |
| **Linux x86_64**               | [![build-linux](https://github.com/openframeworks/apothecary/actions/workflows/build-linux64.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-linux64.yml) | Make, VSCode | C++2b, C17, Package Manager |
| **Linux arm64 (cross)**        | [![build-linux-cross](https://github.com/openframeworks/apothecary/actions/workflows/build-linux-cross.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-linux-cross.yml) | Make | C++2b, C17, Package Manager |
| **Linux armv6 / armv7 (RPi)**  | [![build-linux-rpi](https://github.com/openframeworks/apothecary/actions/workflows/build-linux-rpi.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-linux-rpi.yml) | Make | C++2b, C17, Package Manager |
| **macOS x86_64 / arm64**       | [![build-macos](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml) | Xcode, VSCode | .xcFrameworks, C++2b, C17 |
| **macOS Catalyst arm64 / x86_64** | [![build-macos](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-macos.yml) | Xcode, VSCode | .xcFrameworks, C++2b |
| **xcframeworks**               | [![build-xcframeworks](https://github.com/openframeworks/apothecary/actions/workflows/build-xcframework.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-xcframework.yml) | Xcode, VSCode | .xcFrameworks, C++2b, C17 |
| **iOS arm64 / Simulator**      | [![build-ios](https://github.com/openframeworks/apothecary/actions/workflows/build-ios.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-ios.yml) | Xcode, VSCode | .xcFrameworks, C++2b |
| **tvOS arm64 / Simulator**     | [![build-tvos](https://github.com/openframeworks/apothecary/actions/workflows/build-tvos.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-tvos.yml) | Xcode, VSCode | .xcFrameworks, C++2b |
| **visionOS (xrOS) arm64 / Simulator** | [![build-xros](https://github.com/openframeworks/apothecary/actions/workflows/build-xros.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-xros.yml) | Xcode, VSCode | .xcFrameworks, C++2b |
| **watchOS arm64 / Simulator**  | [![build-watchos](https://github.com/openframeworks/apothecary/actions/workflows/build-watchos.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-watchos.yml) | Xcode, VSCode | .xcFrameworks, C++2b |
| **emscripten / memory64**      | [![build-emscripten](https://github.com/openframeworks/apothecary/actions/workflows/build-emscripten.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-emscripten.yml) | Make | C++17, C17 |
| **Android arm64 / armv7 / x86 / x86_64** | [![build-android](https://github.com/openframeworks/apothecary/actions/workflows/build-android.yml/badge.svg)](https://github.com/openframeworks/apothecary/actions/workflows/build-android.yml) | NDK r29 (`29.0.14206865`), SDK 37, API 25 | CMake |

## Requirements

* Bash shell environment with: `curl`, `tar`, `unzip`, `patch`, `sed`, `make`, `automake`
* C/C++ compiler: gcc and/or llvm (macOS)
* [CMake](https://cmake.org)
* git
* Xcode + iOS SDK (to build for iOS/tvOS/visionOS/watchOS)
* Android SDK + NDK (to build for Android)

macOS and Linux ship with Bash already. On Windows:

* Install [VS Build Tools](https://visualstudio.microsoft.com/downloads/?q=build+tools) and [CMake](https://cmake.org/download/)
* Run from **Git Bash** (comes with [Git for Windows](https://git-scm.com/download/win)), or from a MINGW32/MINGW64 shell if using MSYS2
* Python, via the [Microsoft Store](https://www.microsoft.com/store/productId/9NRWMJP3717K)

## Quick start

*Paths below are relative to the base openFrameworks dir when used from an OF checkout.*

| Location | Path |
|---|---|
| Core OF formulas | `scripts/apothecary/formulas` |
| Addon formulas | `addons/ofxAddonName/scripts/formulas` |
| Default build dir | `scripts/apothecary/build` |
| Default core libs dest | `libs` |

```bash
# update a single core library
./apo update poco

# update all core libraries
./apo update core

# update an addon / all addons
./apo update ofxAssimpModelLoader
./apo update addons

# cross-compile for another platform
./apo -t ios update core          # or: TYPE=ios ./apo update core
./apo -t android -a arm64 update core

# see everything apothecary can do
./apo --help
```

`./apo` is the friendly CLI front-end (`scripts/apo.sh`) — use it for day-to-day and scripted/agent use (see `scripts/AGENTS.md` for the full non-interactive command contract). It wraps the underlying engine at `apothecary/apothecary`, which you can also call directly with the classic flag syntax:

```bash
./apothecary/apothecary -t osx -a arm64 -j 6 update opencv
```

### Commands

| Command | Description |
|---|---|
| `update` | download, build, and copy library files |
| `download` | download the library source |
| `build` | build the library |
| `prepare` | prepare the library source for building |
| `copy` | copy library files into the libs dir |
| `clean` | clean the library build |
| `remove` | remove the library from the build cache |
| `remove-lib` | remove the library from the libs dir |
| `remove-all` | remove the library from the build cache and libs dir |

### Options

| Option | Description |
|---|---|
| `-t` | build type: `osx`, `macos`, `ios`, `tvos`, `xros`, `watchos`, `catos`, `android`, `linux`, `vs`, `msys2`, `emscripten` (auto-detected from host if omitted) |
| `-a` | architecture, e.g. `arm64`, `x86_64` (target-dependent) |
| `-b` | build dir (default: `$APOTHECARY_DIR/build`) |
| `-d` | compiled libs destination dir (default: OF core `libs` dir, or `addons/addonName/libs` for addons) |
| `-v` | verbose mode |
| `-g` | git mode — prefer git over source tarballs where possible |
| `-s` | git tag to select a custom library version (requires `-g`) |
| `-h` | usage help |

All options must be given **before** the command.

## Docker

For local testing without waiting on CI, prebuilt Dockerfiles for Linux, Android, and emscripten are in [`docker/`](docker/README.md).

## Writing formulas

Start from `apothecary/doc/formula_template.sh`, which is fully commented, and look at an existing formula for the platform/build system you're targeting. Full documentation on the formula API, variables, dependencies, and conventions lives in [`apothecary/README.md`](apothecary/README.md).

---

2014 openFrameworks team
2013 Dan Wilcox \<danomatika@gmail.com\>, supported by the CMU [Studio for Creative Inquiry](http://studioforcreativeinquiry.org/)
2024–2026 Dan Rosser
