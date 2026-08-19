# Formula Version Matrix

**Repo:** openFrameworks apothecary  
**Generated:** 2026-08-03  
**Purpose:** Snapshot of each formula’s **pinned** version vs **upstream latest**, plus remote source. For humans and AI agents doing dependency bumps.

> Versions live in formula scripts under `apothecary/formulas/` (`VER=` / `VERSION=` / `GIT_TAG=`).  
> Re-scan anytime:
> ```bash
> rg -n '^(VER|VERSION|GIT_TAG|GIT_URL)=' apothecary/formulas
> ```

### Status legend

| Status | Meaning |
|--------|---------|
| **current** | Pinned version matches recommended/latest stable for that track |
| **behind** | Newer stable release exists on the same major track |
| **major-behind** | Newer **major** exists (upgrade may break OF / ABI / API) |
| **pinned-dev** | Intentionally on RC, commit, fork, or non-release pin |
| **stale** | Far behind; often inactive formula or OF-specific freeze |
| **vendor** | Prebuilt / OF-hosted binary, not a normal source pin |
| **n/a** | No clear comparable “latest” (branch, fork, or custom) |

### Track notes (OF-safe defaults)

| Library | Preferred track | Why |
|---------|-----------------|-----|
| OpenSSL | **4.0.1** (cmake branch `4.0`) · fallback LTS **3.5.x** | PR #562 tests 4.0.1; openssl-cmake 4.0 needs provider SOURCES patch |
| OpenCV | **4.x** (not 5.x yet) | OF still on 4.x API surface |
| libpng | **1.6.x** stable (not 1.7 beta) | 1.7 still beta |
| libxml2 | **2.13.x** or careful 2.14/2.15 | Major minor jumps can break consumers |
| Assimp | **5.4.x** | Pinned to the last known working release after 6.0.5 CI regressions |

---

## Core libraries (alphabetical)

| Formula | Current (pinned) | Latest upstream | Status | Remote source | Formula path |
|---------|------------------|-----------------|--------|---------------|--------------|
| **angle** | `2026.08.13` (`7e8009eb2c42996fe6e7337bf8d12e1cfe4a1b80`) | google/angle GN; GLES→D3D11 on VS, GLES→Metal on osx/ios/tvos/catos/xros (not metalangle) | pinned-dev | https://github.com/google/angle | `apothecary/formulas/angle/angle.sh` |
| **assimp** | `5.4.3` | `v6.0.5` | compatibility pin | https://github.com/assimp/assimp | `apothecary/formulas/assimp.sh` |
| **boost** | `1.66.0` | `boost-1.91.0` (stable); `1.92.0.beta1` | stale | https://www.boost.org / https://github.com/boostorg/boost · tarball via jfrog artifactory in formula | `apothecary/formulas/boost/boost.sh` |
| **brotli** | `1.2.0` | `v1.2.0` | current | https://github.com/google/brotli | `apothecary/formulas/brotli.sh` |
| **cairo** | `1.18.4` | `1.18.4` | current | https://gitlab.freedesktop.org/cairo/cairo · releases https://www.cairographics.org/releases/ | `apothecary/formulas/cairo/cairo.sh` |
| **curl** | `8.19.0` | `curl-8_21_0` / `8.21.0` | compatibility pin | https://github.com/curl/curl | `apothecary/formulas/curl/curl.sh` |
| **fmt** | `12.2.0` | `12.2.0` | current | https://github.com/fmtlib/fmt | `apothecary/formulas/fmt/fmt.sh` |
| **FreeImage** | `3.19.13` | `3.19.13` | current | https://github.com/danoli3/FreeImage (OF fork) | `apothecary/formulas/FreeImage/FreeImage.sh` |
| **freetype** | `2.14.3` | `VER-2-14-3` / `2.14.3` | current | https://github.com/freetype/freetype · https://freetype.org | `apothecary/formulas/freetype/freetype.sh` |
| **glew** | `2.3.1` | `glew-2.3.1` | current | https://github.com/nigels-com/glew | `apothecary/formulas/glew/glew.sh` |
| **glon12** | Mesa `26.0.4` | Mesa 26.0.x (D3D12 gallium) | pinned-dev | https://archive.mesa3d.org · https://docs.mesa3d.org/drivers/d3d12.html | `apothecary/formulas/glon12.sh` |
| **glfw** | `3.5.1` | `3.5.1` | current | https://github.com/glfw/glfw | `apothecary/formulas/glfw.sh` |
| **glm** | `1.0.3` | `1.0.3` | current | https://github.com/g-truc/glm | `apothecary/formulas/glm/glm.sh` |
| **gstreamer** | `1.24.0` | `1.28.5` (stable line); `1.29.2` newer | behind | https://gitlab.freedesktop.org/gstreamer/gstreamer | `apothecary/formulas/gstreamer.sh` |
| **json** (nlohmann) | `3.12.0` | `v3.12.0` | current | https://github.com/nlohmann/json | `apothecary/formulas/json.sh` |
| **kiss** (kissfft) | `131.2.0` | `131.2.0` | current | https://github.com/mborgerding/kissfft | `apothecary/formulas/kiss/kiss.sh` |
| **libpng** | `1.6.58` | `v1.6.58` stable · `v1.7.0beta89` (beta) | current | https://github.com/pnggroup/libpng (download); SF git listed as `GIT_URL` | `apothecary/formulas/libpng/libpng.sh` |
| **libssh2** | `1.11.0-dev` | `libssh2-1.11.1` | behind / pinned-dev | https://github.com/libssh2/libssh2 | `apothecary/formulas/libssh2.sh` |
| **libusb** | `1.0.30` | `v1.0.30` | current | https://github.com/libusb/libusb | `apothecary/formulas/libusb/libusb.sh` |
| **libxml2** | `2.13.9` | `v2.15.3` (also `v2.14.6`, `v2.13.9` on 2.13 line) | major-behind* | https://github.com/GNOME/libxml2 | `apothecary/formulas/libxml2/libxml2.sh` |
| **metalangle** | `1.0` (`ec925142edeb1da3158fd8710ecc6dc2fb1f1f97`) | kakashidinho fork frozen 2023-02-11; google/angle is a different tree (PR #533) | pinned-dev | https://github.com/kakashidinho/metalangle | `apothecary/formulas/metalangle/metalangle.sh` |
| **dawn** | `2026.07.31` (`cd2d5a667d1140af6e89f4c4c24f6545e1d5d2d7`) | ofLibs pin (Dawn `v20260731.171941`); rolling chromium | pinned-dev | https://dawn.googlesource.com/dawn · mirror https://github.com/google/dawn | `apothecary/formulas/dawn/dawn.sh` |
| **opencv** | `4.14.0` | `5.0.0` latest · **`4.14.0` latest 4.x** | current (4.x track) | https://github.com/opencv/opencv · contrib: https://github.com/opencv/opencv_contrib | `apothecary/formulas/opencv/opencv.sh` |
| **openssl** | `4.0.1` (+ cmake wrapper `VER_TAG=4.0`) | `openssl-4.0.1` · LTS still `3.5.7` | current (4.0 track, experimental for OF) | Source: https://github.com/openssl/openssl · CMake wrapper: https://github.com/danoli3/openssl-cmake (`4.0`) · Site: https://www.openssl.org | `apothecary/formulas/openssl/openssl.sh` |
| **pixman** | `0.46.4` | `pixman-0.46.4` | current | https://gitlab.freedesktop.org/pixman/pixman · https://cairographics.org/releases | `apothecary/formulas/pixman/pixman.sh` |
| **poco** | `1.15.3` (`poco-1.15.3-release`) | `poco-1.15.3-release` | current | https://github.com/pocoproject/poco | `apothecary/formulas/poco/poco.sh` |
| **portaudio** | `stable_v19_20110326` | `v19.7.0` | stale | https://github.com/PortAudio/portaudio (upstream); formula URL empty / legacy tarball name | `apothecary/formulas/portaudio.sh` |
| **pugixml** | `1.16` | `v1.16` | current | https://github.com/zeux/pugixml | `apothecary/formulas/pugixml.sh` |
| **rtAudio** | `6.0.1` | `6.0.1` | current | https://github.com/thestk/rtaudio | `apothecary/formulas/rtAudio/rtAudio.sh` |
| **shaderc** | commit `ff84893…` | tag `v2026.3` (rolling; commit pins common) | pinned-dev | https://github.com/google/shaderc | `apothecary/formulas/shaderc.sh` |
| **svgtiny** | `0.1.8` | netsurf package line (verify on netsurf site) | n/a | `git://git.netsurf-browser.org/libsvgtiny.git` | `apothecary/formulas/svgtiny/svgtiny.sh` |
| **tess2** | `1.0.2` | `v1.0.2` | current | https://github.com/memononen/libtess2 | `apothecary/formulas/tess2/tess2.sh` |
| **uriparser** | `1.0.2` | `uriparser-1.0.2` | current | https://github.com/uriparser/uriparser | `apothecary/formulas/uriparser/uriparser.sh` |
| **utf8** (utfcpp) | `4.1.1` | `v4.1.1` | current | https://github.com/nemtrif/utfcpp | `apothecary/formulas/utf8.sh` |
| **videoInput** | `master` | branch/legacy tags only | pinned-dev | https://github.com/ofTheo/videoInput | `apothecary/formulas/videoInput.sh` |
| **zlib** | `1.3.2` | `v1.3.2` | current | https://github.com/madler/zlib | `apothecary/formulas/zlib/zlib.sh` |

\*libxml2: on purpose staying on **2.13.9** (latest 2.13.x). Upstream latest is **2.15.3**.

---

## Vendor / prebuilt formulas

| Formula | Current | Latest | Status | Remote source | Formula path |
|---------|---------|--------|--------|---------------|--------------|
| **fmod** | `44459` (build id) | OF CI artifact | vendor | http://openframeworks.cc/ci/fmod | `apothecary/formulas/fmod.sh` |
| **fmodex** | `44459` (build id) | OF CI artifact | vendor | http://openframeworks.cc/ci/fmodex/ | `apothecary/formulas/fmodex.sh` |

---

## Build depends (`_depends/`)

| Formula | Current | Latest | Status | Remote source | Formula path |
|---------|---------|--------|--------|---------------|--------------|
| **automake** | `1.16.4` | `1.18.1` | behind | https://ftp.gnu.org/gnu/automake/ | `apothecary/formulas/_depends/automake.sh` |
| **pkg-config** | `0.29.2` | `0.29.2` (classic); pkgconf is modern fork | current / legacy | https://pkgconfig.freedesktop.org · git anongit.freedesktop.org | `apothecary/formulas/_depends/pkg-config.sh` |

---

## Compact “who needs a bump?” view

### Already on latest (recommended track)

`assimp` · `brotli` · `cairo` · `curl` · `fmt` · `FreeImage` · `freetype` · `glew` · `glfw` · `glm` · `json` · `kiss` · `libpng` (1.6) · `libusb` · `opencv` (4.x) · `openssl` (4.0.1) · `pixman` · `poco` · `pugixml` · `rtAudio` · `tess2` · `uriparser` · `utf8` · `zlib`

### Behind / worth reviewing

| Formula | Current → candidate | Notes |
|---------|---------------------|--------|
| **boost** | `1.66.0` → `1.91.0` | Huge jump; formula largely legacy |
| **gstreamer** | `1.24.0` → `1.28.5` | Stable line update |
| **libssh2** | `1.11.0-dev` → `1.11.1` | Prefer release over `-dev` |
| **libxml2** | `2.13.9` → `2.14.6` / `2.15.3` | Test carefully |
| **portaudio** | `20110326` → `v19.7.0` | Very stale pin |
| **automake** | `1.16.4` → `1.18.1` | Host tool, not shipped lib |
| **shaderc** | commit pin → `v2026.3` | Optional tag refresh |

### Major upgrades (do not do casually)

| Formula | Current track | Newer major | Risk |
|---------|---------------|-------------|------|
| **openssl** | 4.0.1 (active pin) | — | Was 3.5 LTS; 4.0 needs openssl-cmake `4.0` + provider SOURCES patch |
| **opencv** | 4.14 | 5.0 | API / module changes |
| **libpng** | 1.6.58 | 1.7 beta | Not stable yet |

---

## Source URL cheat sheet (download vs git)

| Formula | Primary download / clone used by formula |
|---------|------------------------------------------|
| assimp | `github.com/assimp/assimp` tags `v$VER` |
| boost | boostorg jfrog release tarball |
| brotli | `github.com/google/brotli` `v$VER` |
| cairo | cairographics.org releases / freedesktop git |
| curl | `github.com/curl/curl` release `curl-$VER_D` |
| fmt | `github.com/fmtlib/fmt` tag `$VER` |
| FreeImage | `github.com/danoli3/FreeImage` tag `3.19.13` |
| freetype | `github.com/freetype/freetype` tag `VER-X-Y-Z` |
| glew | `github.com/nigels-com/glew` release tarball |
| glfw | `github.com/glfw/glfw` tag `$VER` |
| glm | `github.com/g-truc/glm` branch/tag `$GIT_TAG` |
| json | `github.com/nlohmann/json` tag `v$VER` |
| libpng | `github.com/pnggroup/libpng` tag `v$VER` |
| libusb | `github.com/libusb/libusb` tag `v$VER` |
| libxml2 | `github.com/GNOME/libxml2` tag `v$VER` |
| opencv | `github.com/opencv/opencv` (+ contrib) tag `$VER` |
| openssl | openssl.org/GitHub source `$VER` + `danoli3/openssl-cmake` branch `$VER_TAG` |
| pixman | cairographics.org releases / pixman git |
| poco | `github.com/pocoproject/poco` tag `poco-$VER-release` |
| pugixml | `github.com/zeux/pugixml` release tarball |
| rtAudio | `github.com/thestk/rtaudio` |
| uriparser | `github.com/uriparser/uriparser` tag `uriparser-$VER` |
| utf8 | `github.com/nemtrif/utfcpp` tag `v$VER` |
| zlib | `github.com/madler/zlib` release `v$VER` |

---

## How to refresh this matrix

1. **Read pins:**
   ```bash
   rg -n '^(VER|VERSION|GIT_TAG|GIT_URL)=' apothecary/formulas
   ```
2. **Check latest (examples):**
   ```bash
   curl -sL https://api.github.com/repos/fmtlib/fmt/releases/latest | jq -r .tag_name
   curl -sL https://api.github.com/repos/openssl/openssl/releases/latest | jq -r .tag_name
   ```
3. **Bump formula** `VER=` / checksums / `BUILD_ID` as needed.
4. **Test on macOS arm64:**
   ```bash
   ./apothecary/apothecary -t osx -a arm64 -f -d ./out update <lib>
   ```
5. Full command reference: [`README_AI.md`](README_AI.md)

---

## Machine-friendly index (YAML)

```yaml
# formula_version_matrix snapshot 2026-08-03
generated: 2026-08-03
formulas:
  assimp:     { current: "5.4.3",    latest: "6.0.5",    status: compatibility_pin, source: "https://github.com/assimp/assimp" }
  boost:      { current: "1.66.0",   latest: "1.91.0",   status: stale,        source: "https://github.com/boostorg/boost" }
  brotli:     { current: "1.2.0",    latest: "1.2.0",    status: current,      source: "https://github.com/google/brotli" }
  cairo:      { current: "1.18.4",   latest: "1.18.4",   status: current,      source: "https://gitlab.freedesktop.org/cairo/cairo" }
  curl:       { current: "8.19.0",   latest: "8.21.0",   status: compatibility_pin, source: "https://github.com/curl/curl" }
  fmt:        { current: "12.2.0",   latest: "12.2.0",   status: current,      source: "https://github.com/fmtlib/fmt" }
  FreeImage:  { current: "3.19.13",  latest: "3.19.13",  status: current,      source: "https://github.com/danoli3/FreeImage" }
  freetype:   { current: "2.14.3",   latest: "2.14.3",   status: current,      source: "https://github.com/freetype/freetype" }
  glew:       { current: "2.3.1",    latest: "2.3.1",    status: current,      source: "https://github.com/nigels-com/glew" }
  glfw:       { current: "3.5.1",    latest: "3.5.1",    status: current,      source: "https://github.com/glfw/glfw" }
  glm:        { current: "1.0.3",    latest: "1.0.3",    status: current,      source: "https://github.com/g-truc/glm" }
  gstreamer:  { current: "1.24.0",   latest: "1.28.5",   status: behind,       source: "https://gitlab.freedesktop.org/gstreamer/gstreamer" }
  json:       { current: "3.12.0",   latest: "3.12.0",   status: current,      source: "https://github.com/nlohmann/json" }
  kiss:       { current: "131.2.0",  latest: "131.2.0",  status: current,      source: "https://github.com/mborgerding/kissfft" }
  libpng:     { current: "1.6.58",   latest: "1.6.58",   status: current,      source: "https://github.com/pnggroup/libpng" }
  libssh2:    { current: "1.11.0-dev", latest: "1.11.1", status: behind,       source: "https://github.com/libssh2/libssh2" }
  libusb:     { current: "1.0.30",   latest: "1.0.30",   status: current,      source: "https://github.com/libusb/libusb" }
  libxml2:    { current: "2.13.9",   latest: "2.15.3",   status: major-behind, source: "https://github.com/GNOME/libxml2" }
  opencv:     { current: "4.14.0",   latest: "5.0.0",    status: current,      track: "4.x", source: "https://github.com/opencv/opencv" }
  openssl:    { current: "4.0.1",    latest: "4.0.1",    status: current,      track: "4.0", source: "https://github.com/openssl/openssl", cmake: "https://github.com/danoli3/openssl-cmake", cmake_branch: "4.0" }
  pixman:     { current: "0.46.4",   latest: "0.46.4",   status: current,      source: "https://gitlab.freedesktop.org/pixman/pixman" }
  poco:       { current: "1.15.3",   latest: "1.15.3",   status: current,      source: "https://github.com/pocoproject/poco" }
  portaudio:  { current: "stable_v19_20110326", latest: "v19.7.0", status: stale, source: "https://github.com/PortAudio/portaudio" }
  pugixml:    { current: "1.16",     latest: "1.16",     status: current,      source: "https://github.com/zeux/pugixml" }
  rtAudio:    { current: "6.0.1",    latest: "6.0.1",    status: current,      source: "https://github.com/thestk/rtaudio" }
  shaderc:    { current: "ff84893",  latest: "v2026.3",  status: pinned-dev,   source: "https://github.com/google/shaderc" }
  tess2:      { current: "1.0.2",    latest: "1.0.2",    status: current,      source: "https://github.com/memononen/libtess2" }
  uriparser:  { current: "1.0.2",    latest: "1.0.2",    status: current,      source: "https://github.com/uriparser/uriparser" }
  utf8:       { current: "4.1.1",    latest: "4.1.1",    status: current,      source: "https://github.com/nemtrif/utfcpp" }
  videoInput: { current: "master",   latest: "master",   status: pinned-dev,   source: "https://github.com/ofTheo/videoInput" }
  zlib:       { current: "1.3.2",    latest: "1.3.2",    status: current,      source: "https://github.com/madler/zlib" }
  fmod:       { current: "44459",    latest: "vendor",   status: vendor,       source: "http://openframeworks.cc/ci/fmod" }
  fmodex:     { current: "44459",    latest: "vendor",   status: vendor,       source: "http://openframeworks.cc/ci/fmodex/" }
  automake:   { current: "1.16.4",   latest: "1.18.1",   status: behind,       source: "https://ftp.gnu.org/gnu/automake/" }
  pkg-config: { current: "0.29.2",   latest: "0.29.2",   status: current,      source: "https://pkgconfig.freedesktop.org" }
```

---

*Last upstream check: 2026-08-03 (GitHub/GitLab APIs + project release pages). Refresh dates when bumping.*
