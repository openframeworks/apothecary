# Formula Version Matrix

**Repo:** openFrameworks apothecary  
**Generated:** 2026-09-14  
**Source of truth:** `VER=` / `VERSION=` / `GIT_TAG=` / `SOURCE_COMMIT=` in `apothecary/formulas/`  
**Upstream check:** GitHub/GitLab APIs, 2026-09-14

```bash
rg -n '^(VER|VERSION|GIT_TAG|GIT_URL|SOURCE_COMMIT)=' apothecary/formulas
```

### Status legend

| Status | Meaning |
|--------|---------|
| **current** | Pinned version is latest stable on the track we intend to ship |
| **behind** | Newer stable exists on the **same** track — candidate bump |
| **major-behind** | Newer **major/minor track** exists; we stay put on purpose |
| **compatibility pin** | We know a newer release exists and **rejected** it (CI/API) |
| **pinned-dev** | SHA, fork, RC, or rolling tree — not a version tag |
| **stale** | Far behind **and** formula is unused or frozen |
| **vendor** | Prebuilt OF-hosted binary |
| **n/a** | No comparable upstream “latest” |

A **pin** is not “we forgot to bump”. If status is compatibility / major-behind / pinned-dev, do **not** bump without a dedicated PR that names the reason below.

---

## Why we pin (policy)

| Track | What we ship | Why |
|-------|----------------|-----|
| **OpenSSL** | **4.0.2** via `danoli3/openssl-cmake` branch `4.0` | OF moved off 3.x onto 4.0 (#562/#590). `openssl-cmake` 3.5 + OpenSSL 3.5.7 failed CI (ML-DSA DTLS macros). LTS **3.5.8** is the rollback track, not the default. **4.1.0-alpha1** is not for OF. |
| **OpenCV** | **4.14.0** (latest 4.x) | OF still uses the 4.x API. **5.0.0** is a major. |
| **libpng** | **1.6.58** (latest 1.6) | **1.7 is still beta** (`v1.7.0beta89`). |
| **libxml2** | **2.13.9** (latest 2.13.x) | 2.14/2.15 (`v2.15.4`) break consumers; stay on 2.13 until OF is tested. |
| **Assimp** | **5.4.3** | Last known-good. **6.0.5** caused CI regressions; do not jump without a dedicated rebuild. |
| **FreeImage** | **3.19.15** (`danoli3/FreeImage`) | OF fork, not SourceForge. Codecs: OpenEXR/WebP/LibRaw ON except **VS LibRaw+JXR off** (C2491 / jxrlib SAL) and **VS ARM64EC OpenEXR off** (`emmintrin.h`). |
| **ANGLE / Dawn / MetalANGLE / GLon12** | SHA pins | Opt-in backends. Not default OF GL. See `AGENTS.md`. |
| **Linux CI compiler** | **GCC 10** | Focal-era CI. Dawn stays **off** Linux core until GCC 11 (`std::bit_cast` / `atomic::wait`). |
| **Android NDK** | YAML `28.2.13676358` | See [Toolchains](#toolchains). Configure currently redirects that string to `ANDROID_NDK_LATEST_HOME` (**r29** on ubuntu-24.04). |

---

## Core libraries

| Formula | Pinned | Latest upstream | Status | Why pinned | Source |
|---------|--------|-----------------|--------|------------|--------|
| **angle** | `2026.08.13` (`7e8009eb2c42996fe6e7337bf8d12e1cfe4a1b80`) | google/angle main (rolling) | pinned-dev | Chromium SHA. GLES→D3D11 on VS. Apple `gn gen` failed CI (#589) — **off core**. Not metalangle. | https://github.com/google/angle |
| **assimp** | `5.4.3` | `v6.0.5` | compatibility pin | 6.x failed CI. Last known-good 5.4.3. | https://github.com/assimp/assimp |
| **boost** | `1.66.0` | `boost-1.92.0` | stale | `FORMULA_TYPES=()` — unused. filesystem/system only until C++ std; OF is C++17+. Do not treat as a live dep. | boostorg tarball |
| **brotli** | `1.2.0` | `v1.2.0` | current | Latest stable. | https://github.com/google/brotli |
| **cairo** | `1.18.4` | `1.18.4` | current | Latest stable. | https://gitlab.freedesktop.org/cairo/cairo |
| **curl** | `8.21.0` | `curl-8_22_0` / `8.22.0` | behind | Just shipped 8.21.0 (#574/#579) with nghttp2/3 + ngtcp2 + libssh2. **8.22.0 is a one-point bump**, not a pin. | https://github.com/curl/curl |
| **dawn** | `2026.07.31` (`cd2d5a667d1140af6e89f4c4c24f6545e1d5d2d7`) | Dawn `v20260911.162847` (rolling) | pinned-dev | ofLibs-era SHA. `DAWN_BUILD_MONOLITHIC_LIBRARY=STATIC`. Linux off until GCC 11. watchOS: no Metal. | https://dawn.googlesource.com/dawn |
| **fmt** | `12.2.0` | `12.2.0` | current | Latest stable. | https://github.com/fmtlib/fmt |
| **FreeImage** | `3.19.15` | `3.19.15` | current | OF fork (`danoli3/FreeImage`). Security 3.19.15. VS codec cuts: LibRaw/JXR off; ARM64EC OpenEXR off. | https://github.com/danoli3/FreeImage |
| **freetype** | `2.14.3` | `VER-2-14-3` | current | Latest 2.14. | https://github.com/freetype/freetype |
| **glew** | `2.3.1` | `glew-2.3.1` | current | Latest stable. | https://github.com/nigels-com/glew |
| **glon12** | Mesa `26.0.4` | Mesa `26.2.2` | pinned-dev | VS-only GL→D3D12. SHA256 `6d91541e…`. Newer Mesa is a backend bump, not a silent formula bump. | https://archive.mesa3d.org |
| **glfw** | `3.5.1` | `3.5.1` | current | Latest stable. | https://github.com/glfw/glfw |
| **glm** | `1.0.3` | `1.0.3` | current | Latest stable. | https://github.com/g-truc/glm |
| **gstreamer** | `1.24.0` (`b125253c…`) | `1.28.7` stable; `1.29.2` newer | behind | linux/osx only. No OF API freeze documented — **just not bumped**. Candidate: 1.28.7. | https://gitlab.freedesktop.org/gstreamer/gstreamer |
| **json** (nlohmann) | `3.12.0` | `v3.12.0` | current | Latest stable. | https://github.com/nlohmann/json |
| **kiss** (kissfft) | `131.2.0` | `131.2.0` | current | Latest stable. | https://github.com/mborgerding/kissfft |
| **libpng** | `1.6.58` | `v1.6.58` stable · `v1.7.0beta89` | current (1.6 track) | Stay on 1.6 until 1.7 is stable. | https://github.com/pnggroup/libpng |
| **libssh2** | `1.11.1` | `libssh2-1.11.1` | current | Release pin (was wrongly listed as `1.11.0-dev`). cURL SSH backend. | https://github.com/libssh2/libssh2 |
| **libusb** | `1.0.30` | `v1.0.30` | current | Latest stable. | https://github.com/libusb/libusb |
| **libxml2** | `2.13.9` | `v2.15.4` (2.13 latest = 2.13.9) | major-behind | **On purpose** latest 2.13.x. 2.14/2.15 need an OF test pass. | https://github.com/GNOME/libxml2 |
| **metalangle** | `1.0` (`ec925142edeb1da3158fd8710ecc6dc2fb1f1f97`) | kakashidinho frozen 2023-02-11 | pinned-dev | 2022 Metal overlay + SPIRV-Cross `f38cbeb8`. **Never** put a 2025+ Chromium SHA here — that belongs on `angle`. | https://github.com/kakashidinho/metalangle |
| **nghttp2** | `1.70.0` | `v1.70.0` | current | cURL HTTP/2. | https://github.com/nghttp2/nghttp2 |
| **nghttp3** | `1.18.0` | `v1.18.0` | current | cURL HTTP/3. | https://github.com/ngtcp2/nghttp3 |
| **ngtcp2** | `1.25.0` | `v1.25.0` | current | cURL HTTP/3/QUIC. | https://github.com/ngtcp2/ngtcp2 |
| **opencv** | `4.14.0` | `5.0.0` latest · **`4.14.0` latest 4.x** | current (4.x track) | OF 4.x API. Do not take 5.0 without an OF renderer/module pass. | https://github.com/opencv/opencv |
| **openssl** | `4.0.2` + cmake `VER_TAG=4.0` | `openssl-4.0.2` · LTS `3.5.8` · `4.1.0-alpha1` | current (4.0 track) | 4.0 via `danoli3/openssl-cmake`. Not 3.5 (CI fail). Not 4.1 alpha. | https://github.com/openssl/openssl · cmake https://github.com/danoli3/openssl-cmake |
| **pixman** | `0.46.4` | `pixman-0.46.4` | current | Latest stable. | https://gitlab.freedesktop.org/pixman/pixman |
| **poco** | `1.15.3` | `poco-1.15.3-release` | current | Latest stable. | https://github.com/pocoproject/poco |
| **portaudio** | `stable_v19_20110326` | `v19.7.0` | stale | `FORMULA_TYPES=()` — **not built**. 2011 SourceForge tarball. Ignore unless someone revives it (then `v19.7.0`). | http://www.portaudio.com |
| **pugixml** | `1.16` | `v1.16` | current | Latest stable. | https://github.com/zeux/pugixml |
| **rtAudio** | `6.0.1` | `6.0.1` | current | Tag in formula is `master` but `VER=6.0.1` matches latest release. | https://github.com/thestk/rtaudio |
| **shaderc** | `ff84893dd52d28f0b1737d2635733d952013bd9c` | tag `v2026.4` | pinned-dev | `FORMULA_TYPES=()` — unused. SHA is shaderc “known-good”. Only bump with SPIRV/Glslang stack. | https://github.com/google/shaderc |
| **svgtiny** | `0.1.8` | netsurf package line | n/a | NetSurf libsvgtiny; not a GitHub release train. | `git://git.netsurf-browser.org/libsvgtiny.git` |
| **tess2** | `1.0.2` | `v1.0.2` | current | Latest stable (`GIT_TAG=master` in formula — verify checkout). | https://github.com/memononen/libtess2 |
| **uriparser** | `1.0.2` | `uriparser-1.0.2` | current | Latest stable. | https://github.com/uriparser/uriparser |
| **utf8** (utfcpp) | `4.1.1` | `v4.2.0` | behind | Header-only. **4.2.0 is a straightforward candidate.** | https://github.com/nemtrif/utfcpp |
| **videoInput** | `master` (`261bfeee…`) | branch only | pinned-dev | ofTheo fork SHA. Windows capture. | https://github.com/ofTheo/videoInput |
| **zlib** | `1.3.2` | `v1.3.2` | current | Latest stable. | https://github.com/madler/zlib |

---

## Vendor / prebuilt

| Formula | Pinned | Status | Why pinned | Source |
|---------|--------|--------|------------|--------|
| **fmod** | build id `44459` | vendor | OF-hosted prebuilt, not compiled here. | http://openframeworks.cc/ci/fmod |
| **fmodex** | build id `44459` | vendor | Legacy FMOD Ex prebuilt. | http://openframeworks.cc/ci/fmodex/ |

---

## Build depends (`_depends/`)

| Formula | Pinned | Latest | Status | Why pinned | Source |
|---------|--------|--------|--------|------------|--------|
| **automake** | `1.16.4` | `1.18.1` | behind | Host tool, not shipped in OF libs. Safe to bump in isolation. | https://ftp.gnu.org/gnu/automake/ |
| **pkg-config** | `0.29.2` | `0.29.2` (classic); pkgconf is the fork | current / legacy | Classic pkg-config. Do not silently swap for pkgconf. | https://pkgconfig.freedesktop.org |

---

## Toolchains (not formulas — still pins)

| Tool | What CI declares | What actually runs | Why / watch |
|------|------------------|--------------------|-------------|
| **Emscripten** | `6.0.8` (`build-emscripten.yml`) | 6.0.8 | Current pin (#591). |
| **Linux GCC** | gcc-10 | gcc-10 on Linux/RPi jobs | Keep until Dawn/C++20 libstdc++ is accepted. |
| **VS** | VS2022 (17) + VS2026 (18) | both | Dual matrix. |
| **Android SDK** | matrix `36.0.0` | Runner has 34–37; **Studio is not installed** | cmdline-tools 12.0 on ubuntu-24.04. |
| **Android NDK** | matrix `28.2.13676358` | Image has 27.3 (default `ANDROID_NDK_ROOT`), **28.2**, **29.0.14206865** (`ANDROID_NDK_LATEST_HOME`) | `android_configure.sh` maps `NDK=28.2.13676358` → **`ANDROID_NDK_LATEST_HOME` = r29**. YAML pin ≠ compiler. API matrix is **24**. |
| **Android Studio** | README still says “NDK 23, Android Studio” | **Not used in Actions** | Stale README. Local Studio stable is Quail 4 (2026.1.4). |

---

## What needs updating

### Do next (same track, no policy freeze)

| Item | Pinned → candidate | Why it is safe-ish |
|------|--------------------|--------------------|
| **curl** | `8.21.0` → `8.22.0` | One point; we already take 8.21 + HTTP/3 stack. |
| **utf8** | `4.1.1` → `4.2.0` | Header-only. |
| **gstreamer** | `1.24.0` → `1.28.7` | Same 1.x line; linux/osx only; needs a real rebuild. |
| **automake** | `1.16.4` → `1.18.1` | Host-only. |
| **Android NDK mapping** | YAML 28.2 → actually r29 | Either pin `NDK_ROOT` to the 28.2 path, or declare r29 on purpose. Do not leave the redirect implicit. |
| **README Android line** | “NDK 23, Android Studio” | Lies; Actions uses SDK cmdline + NDK, no Studio. |

### Optional / backend (dedicated PR)

| Item | Pinned → candidate | Why it is a project |
|------|--------------------|---------------------|
| **glon12** | Mesa 26.0.4 → 26.2.2 | VS GL→D3D12 only. |
| **shaderc** | SHA `ff84893` → `v2026.4` | Formula unused (`FORMULA_TYPES=()`). |
| **dawn / angle** | current SHAs → newer Chromium | Rolling; needs `AGENTS.md` pin table + CI. |
| **tess2 / rtAudio `GIT_TAG=master`** | tag vs `VER` | Align git tag with `VER` so checkouts are reproducible. |

### Do **not** bump without an explicit decision

| Item | Stays | Blocker |
|------|-------|---------|
| **assimp** | 5.4.3 | 6.0.5 CI regressions |
| **opencv** | 4.14.0 | 5.0 is a major |
| **libxml2** | 2.13.9 | 2.15.4 track change |
| **libpng** | 1.6.58 | 1.7 beta |
| **openssl** | 4.0.2 | not 4.1-alpha; not 3.5 unless rolling back |
| **boost / portaudio / shaderc** | as-is | unused formulas |
| **metalangle SHA** | `ec92514` | overlay + SPIRV-Cross pin |
| **FreeImage VS codecs** | LibRaw/JXR off; ARM64EC OpenEXR off | MSVC C2491 / SAL / `emmintrin.h` |
| **Linux Dawn** | off | GCC 10 libstdc++ |

### Already on latest (intended track)

`brotli` · `cairo` · `fmt` · `FreeImage` · `freetype` · `glew` · `glfw` · `glm` · `json` · `kiss` · `libpng` (1.6) · `libssh2` · `libusb` · `nghttp2` · `nghttp3` · `ngtcp2` · `opencv` (4.x) · `openssl` (4.0) · `pixman` · `poco` · `pugixml` · `rtAudio` · `tess2` · `uriparser` · `zlib`

---

## Source URL cheat sheet

| Formula | Download / clone |
|---------|------------------|
| assimp | `github.com/assimp/assimp` `v$VER` |
| boost | boostorg jfrog tarball |
| brotli | `github.com/google/brotli` `v$VER` |
| cairo | cairographics / freedesktop git |
| curl | `github.com/curl/curl` `curl-$VER_D` |
| fmt | `github.com/fmtlib/fmt` tag `$VER` |
| FreeImage | `github.com/danoli3/FreeImage` tag `3.19.15` |
| freetype | `github.com/freetype/freetype` `VER-2-14-3` |
| glew | nigels-com/glew release tarball |
| glfw | `github.com/glfw/glfw` tag `$VER` |
| glm | `github.com/g-truc/glm` `$GIT_TAG` |
| json | `github.com/nlohmann/json` `v$VER` |
| libpng | `github.com/pnggroup/libpng` `v$VER` |
| libssh2 | `github.com/libssh2/libssh2` `libssh2-$VER` |
| libusb | `github.com/libusb/libusb` `v$VER` |
| libxml2 | `github.com/GNOME/libxml2` `v$VER` |
| nghttp2 | `github.com/nghttp2/nghttp2` `v$VER` |
| nghttp3 | `github.com/ngtcp2/nghttp3` `v$VER` |
| ngtcp2 | `github.com/ngtcp2/ngtcp2` `v$VER` |
| opencv | opencv + contrib tag `$VER` |
| openssl | openssl `$VER` + `danoli3/openssl-cmake` `$VER_TAG` |
| pixman | cairographics / pixman git |
| poco | `github.com/pocoproject/poco` `poco-$VER-release` |
| pugixml | `github.com/zeux/pugixml` |
| rtAudio | `github.com/thestk/rtaudio` |
| uriparser | `github.com/uriparser/uriparser` `uriparser-$VER` |
| utf8 | `github.com/nemtrif/utfcpp` `v$VER` |
| zlib | `github.com/madler/zlib` `v$VER` |

---

## How to refresh

1. Re-read pins: `rg -n '^(VER|VERSION|GIT_TAG|SOURCE_COMMIT)=' apothecary/formulas`
2. Check latest: `curl -sL https://api.github.com/repos/<org>/<repo>/releases/latest | jq -r .tag_name`
3. Bump `VER=` / checksum / `BUILD_ID`. If you change **why** it is pinned, edit this file in the same PR.
4. Smoke: `NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=arm64 ./apo update <lib>`
5. CLI contract: [`scripts/AGENTS.md`](scripts/AGENTS.md)

---

## Machine-friendly index (YAML)

```yaml
# formula_version_matrix snapshot 2026-09-14
generated: 2026-09-14
formulas:
  angle:      { current: "2026.08.13", latest: "rolling", status: pinned-dev, pin: "chromium SHA; Apple gn gen off core" }
  assimp:     { current: "5.4.3",    latest: "6.0.5",    status: compatibility_pin, pin: "6.x CI regressions" }
  boost:      { current: "1.66.0",   latest: "1.92.0",   status: stale, pin: "FORMULA_TYPES empty; unused" }
  brotli:     { current: "1.2.0",    latest: "1.2.0",    status: current }
  cairo:      { current: "1.18.4",   latest: "1.18.4",   status: current }
  curl:       { current: "8.21.0",   latest: "8.22.0",   status: behind, pin: "none — one-point bump available" }
  dawn:       { current: "2026.07.31", latest: "v20260911.162847", status: pinned-dev, pin: "SHA; Linux needs GCC 11" }
  fmt:        { current: "12.2.0",   latest: "12.2.0",   status: current }
  FreeImage:  { current: "3.19.15",  latest: "3.19.15",  status: current, pin: "OF fork; VS LibRaw/JXR off; ARM64EC OpenEXR off" }
  freetype:   { current: "2.14.3",   latest: "2.14.3",   status: current }
  glew:       { current: "2.3.1",    latest: "2.3.1",    status: current }
  glon12:     { current: "26.0.4",   latest: "26.2.2",   status: pinned-dev, pin: "Mesa SHA; VS-only" }
  glfw:       { current: "3.5.1",    latest: "3.5.1",    status: current }
  glm:        { current: "1.0.3",    latest: "1.0.3",    status: current }
  gstreamer:  { current: "1.24.0",   latest: "1.28.7",   status: behind, pin: "none documented — not bumped" }
  json:       { current: "3.12.0",   latest: "3.12.0",   status: current }
  kiss:       { current: "131.2.0",  latest: "131.2.0",  status: current }
  libpng:     { current: "1.6.58",   latest: "1.6.58",   status: current, track: "1.6", pin: "1.7 still beta" }
  libssh2:    { current: "1.11.1",   latest: "1.11.1",   status: current }
  libusb:     { current: "1.0.30",   latest: "1.0.30",   status: current }
  libxml2:    { current: "2.13.9",   latest: "2.15.4",   status: major-behind, pin: "stay on 2.13.x" }
  metalangle: { current: "ec92514",  latest: "frozen-2023", status: pinned-dev, pin: "2022 overlay + SPIRV-Cross" }
  nghttp2:    { current: "1.70.0",   latest: "1.70.0",   status: current }
  nghttp3:    { current: "1.18.0",   latest: "1.18.0",   status: current }
  ngtcp2:     { current: "1.25.0",   latest: "1.25.0",   status: current }
  opencv:     { current: "4.14.0",   latest: "5.0.0",    status: current, track: "4.x", pin: "OF 4.x API" }
  openssl:    { current: "4.0.2",    latest: "4.0.2",    status: current, track: "4.0", pin: "openssl-cmake 4.0; not 3.5; not 4.1-alpha" }
  pixman:     { current: "0.46.4",   latest: "0.46.4",   status: current }
  poco:       { current: "1.15.3",   latest: "1.15.3",   status: current }
  portaudio:  { current: "stable_v19_20110326", latest: "v19.7.0", status: stale, pin: "FORMULA_TYPES empty" }
  pugixml:    { current: "1.16",     latest: "1.16",     status: current }
  rtAudio:    { current: "6.0.1",    latest: "6.0.1",    status: current }
  shaderc:    { current: "ff84893",  latest: "v2026.4",  status: pinned-dev, pin: "FORMULA_TYPES empty; known-good SHA" }
  tess2:      { current: "1.0.2",    latest: "1.0.2",    status: current }
  uriparser:  { current: "1.0.2",    latest: "1.0.2",    status: current }
  utf8:       { current: "4.1.1",    latest: "4.2.0",    status: behind, pin: "none — header-only bump" }
  videoInput: { current: "261bfeee", latest: "master",   status: pinned-dev, pin: "ofTheo SHA" }
  zlib:       { current: "1.3.2",    latest: "1.3.2",    status: current }
  fmod:       { current: "44459",    latest: "vendor",   status: vendor }
  fmodex:     { current: "44459",    latest: "vendor",   status: vendor }
  automake:   { current: "1.16.4",   latest: "1.18.1",   status: behind, pin: "host tool" }
  pkg-config: { current: "0.29.2",   latest: "0.29.2",   status: current, pin: "classic pkg-config not pkgconf" }
toolchains:
  emscripten: { current: "6.0.8", status: current }
  linux_gcc:  { current: "10", pin: "Focal CI; Dawn off until GCC 11" }
  android_ndk_yaml: { current: "28.2.13676358", actual_ci: "ANDROID_NDK_LATEST_HOME r29 29.0.14206865", pin: "configure redirects 28.2 string to latest" }
  android_api: { current: "24" }
  android_sdk_yaml: { current: "36.0.0" }
```

---

*Last upstream check: 2026-09-14. If you bump a formula, update the pin reason in the same PR.*
