# RGFW (optional)

Pinned to upstream RGFW 1.8.1, with its source archive verified by SHA-256.
This formula never joins the core library bundles.

| Target | Backend / packaging |
| --- | --- |
| macOS | Cocoa; x86_64 + arm64 XCFramework |
| Windows MSVC | Win32; x64, ARM64, ARM64EC |
| MSYS2 | Win32; mingw64, ucrt64, clang64, clangarm64 |
| Linux | X11 / GLX; shared GCC10 modular jobs for x86_64 and ARM64 |
| Emscripten | Browser / WebGL; threaded wasm32 and memory64 |

RGFW 1.8.1 does not implement Android, iOS, tvOS, watchOS, visionOS or
Mac Catalyst window backends. Do not substitute a desktop backend or ship an
empty archive for these targets. Wayland is experimental upstream and this
release does not include the protocol headers needed to build it; the Linux
package uses X11 (including XWayland on a Wayland desktop).

Build explicitly, for example:

```sh
TYPE=osx ARCH=arm64 NO_COLOR=1 UI_ANIM=0 ./apo update rgfw
TYPE=linux ARCH=64 GCC_VERSION=10 NO_COLOR=1 UI_ANIM=0 ./apo update rgfw
```

Use `#include <rgfw_apothecary.h>` when linking the precompiled library. The
wrapper enables `RGFW_OPENGL`, uses external API declarations instead of the
upstream inline default, and supplies C linkage for C++ consumers. Do **not**
define `RGFW_IMPLEMENTATION` when linking the archive. The original `RGFW.h`
and `XDL.h` are also shipped unchanged for upstream single-header use.

The library provides windowing and OpenGL context helpers, not an
openFrameworks window backend. Applications still need an explicit integration.

Packages include the license and per-binary Pkl metadata. Raw staged libraries
and non-Apple modular packages also include relocatable `cmake/rgfwConfig.cmake`
(`apothecary::rgfw`) and `pkgconfig/rgfw.pc` files. The CMake target and
`pkg-config --static` carry native link dependencies.
For Emscripten, consumers must use the same pthread/memory-width flags as the
selected archive. macOS consumers should link the XCFramework's matching slice.

Linux is built with the shared Linux modular job. Other supported targets use
`build-rgfw-modular.yml`, which plans builds on Linux before starting native
runners, restores compatible artifacts, publishes archives only on trusted
pushes, and records verified per-configuration Pkl records on `build-state`.
PR builds upload inspectable Actions artifacts without changing releases.
