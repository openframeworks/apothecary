# apothecary CLI — agent contract

How AI systems and automation should drive the `apo` CLI. Humans can use the interactive menu; agents must not.

**Entry:** `./apo` (repo root) → `scripts/apo.sh`  
**UI kit:** `scripts/ui.sh`  
**Engine:** `apothecary/apothecary` (real build tool; `apo` is the pretty front-end)

When used **from openFrameworks**, prefer the submodule:

```text
openFrameworks/scripts/apothecary/apo
```

oF’s own agent notes: `openFrameworks/scripts/AGENTS.md` (`of` downloads prebuilts; `apo` compiles formulas).

---

## Rules (always)

1. **Prefer explicit commands** with a library name (or `core`). Never rely on bare `./apo` menus in CI/agents.
2. **Disable chrome:**
   ```bash
   NO_COLOR=1 UI_ANIM=0 ./apo <command> …
   ```
3. **Always set `TYPE` and `ARCH`** when not targeting the host default.
4. **Do not parse spinner / task redraw lines.** Use final `key  value` lines and the engine’s own logs.
5. **Confirms:** `confirmYes` defaults to **yes** on empty Enter. Non-TTY `read` with empty stdin often auto-accepts. Prefer piping `yes` only when you intend to proceed; never hang waiting for a human.
6. **Require a library list** for `update` / `download` / `build` / `clean` / `remove` — no bare action with zero libs.
7. **Direct engine passthrough** is available for unknown verbs if `apothecary/apothecary` exists; still set `TYPE`/`ARCH` via env so the wrapper passes `-t`/`-a`.
8. **Verify every network source before use.** Archive downloads must declare a pinned SHA-256 and call `verify_sha256` before extraction. Git downloads must check out a pinned 40-character commit and call `verify_git_commit`. Run `scripts/audit-formula-checksums.sh` after formula changes.

---

## Commands

| Command | Purpose | Agent notes |
|--------|---------|-------------|
| `apo status` | Host, TYPE/ARCH, paths, formula count | Safe first call |
| `apo formulas` | List formula names | Alias: `libs` |
| `apo platforms` | Build types + arches | |
| `apo version` | CLI version | |
| `apo update <lib…>` | Download + build + copy | Main path; needs lib(s) or `core` |
| `apo download <lib…>` | Sources only | |
| `apo build <lib…>` | Compile only | |
| `apo modular <lib…>` | Stage XCFramework output | Accepts core names, addon names, or formula script paths |
| `apo variant <profile> [build\|package\|all]` | Build an isolated modular variant | Profiles: `opencv-cuda`, `opencv-cuda-ai`; Linux/Windows only |
| `apo clean <lib…>` | Clean build tree | |
| `apo remove <lib…>` | Remove from build cache | |
| `apo help` | Usage | |
| `apo menu` / bare `apo` on TTY | Interactive | **Do not use** in agents |
| `apo demo` | UI preview | Skip in automation |

Unknown commands may **passthrough** to the underlying `apothecary` binary.

---

## Environment

| Variable | Default | Meaning |
|----------|---------|---------|
| `TYPE` | host OS (`osx`, `linux`, …) | Build type (`-t`). Also accepted: `TARGET`. `macos` is normalized to the engine's canonical `osx` target. |
| `ARCH` | host arch | Architecture (`-a`) |
| `FORCE=1` | `0` | Force re-download (`-f`). Alias: `APO_FORCE` |
| `VERBOSE=1` | off | Extra logging (`-v`) |
| `NO_COLOR=1` | off | No ANSI color |
| `UI_ANIM=0` | `1` | No spinners / list animation |
| `OUTPUT_FOLDER` | `<repo>/out` | Install / package output (`-d`) |

After `copy`, `scripts/export_config.sh` writes relocatable `.pc` and `cmake/*Config.cmake` next to each binary (issue #405). Absolute cmake-install prefixes are rewritten to `\${pcfiledir}` / `CMAKE_CURRENT_LIST_DIR`.
| `BUILD_DIR` | `<repo>/build` | Build cache (`-b`) |
| `PACKAGE_LIBS` | unset | Space/comma-separated non-core staging directories for `scripts/package-individual.sh` |
| `OPENCV_EXTRA_DEFINES` | unset | Additional CMake definitions for modular OpenCV variants |

**Valid `TYPE` values (wrapper list):**  
`osx` `macos` `ios` `tvos` `xros` `watchos` `catos` `android` `linux` `vs` `msys2` `emscripten`

**Arch examples:**  
- `osx` / `macos`: `arm64`, `x86_64`  
- Apple mobile: `arm64`, `SIM_arm64`, `x86_64`  
- `android`: e.g. `arm64`, `x86_64` (as supported by scripts)

---

## Paths

| Path | Role |
|------|------|
| repo root | Apothecary project root |
| `apothecary/formulas/` | Library formulas |
| `apothecary/apothecary` | Engine binary/script |
| `out/` | Default `OUTPUT_FOLDER` (built libs) |
| `build/` | Default `BUILD_DIR` (build cache) |

**openFrameworks integration:** set output into OF’s tree, e.g.:

```bash
export OUTPUT_FOLDER="/path/to/openFrameworks/libs"
export BUILD_DIR="/path/to/openFrameworks/scripts/apothecary/build"
```

(or whatever path the OF menu already exports when launching apo).

---

## Recipes (copy/paste)

```bash
export NO_COLOR=1 UI_ANIM=0

# Inspect
./apo status
./apo formulas
./apo platforms

# Host: update one library
./apo update zlib

# Host: core set
./apo update core

# Cross / explicit target
TYPE=android ARCH=arm64 ./apo update openssl
TYPE=osx ARCH=arm64 FORCE=1 ./apo update glfw glm

# Download only / build only
./apo download curl
./apo build curl

# Install into a custom folder (e.g. OF libs)
OUTPUT_FOLDER=/path/to/openFrameworks/libs \
BUILD_DIR=/path/to/apothecary/build \
TYPE=osx ARCH=arm64 \
  ./apo update core
```

---

## Exit codes (current)

| Code | Meaning |
|------|---------|
| `0` | Success (also “cancelled” after a no-confirm in some paths — check logs) |
| non-zero | Missing lib args, engine missing, build failure, unknown command without passthrough |

Bare `./apo` with **no TTY** prints help and exits **1**.

No `--json` / `--quiet` yet. Engine lines are the source of truth for compile errors.

---

## Output parsing (until --json)

From `status` / help footers, prefer lines like:

```text
  host           osx / arm64
  type           osx
  arch           arm64
  out            /…/out
  build          /…/build
  formulas       /…/formulas
```

`formulas` command lists one name per line (after the banner). Ignore task UI redraws.

---

## Anti-patterns

- `./apo` or `./apo menu` in headless agent sessions  
- `apo update` with **no** library names  
- Building `ios` / `android` / multi-arch without user request  
- Assuming `out/` is openFrameworks `libs/` (only if `OUTPUT_FOLDER` was set)  
- Treating prebuilt **download** via OF (`of update libs`) as the same as **compiling** here  
- Parsing gum / braille spinner frames  

---

## Relationship to openFrameworks `of`

| Goal | Tool |
|------|------|
| Download stock prebuilt packages | `of update libs` / `of setup` |
| Check OF tree health | `of status` |
| Compile a formula from source | `apo update <lib>` |
| Install compiled libs into OF | `apo` with `OUTPUT_FOLDER=…/libs` (or OF’s apothecary menu) |

---

## Version

CLI version appears as `cli` / banner (e.g. `0.3.0`). Keep this file aligned with `apo help`.
