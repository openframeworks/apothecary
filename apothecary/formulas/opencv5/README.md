# OpenCV 5 modular package

`opencv5` is a separate OpenCV 5.0.0 formula cloned from `opencv`. The existing
OpenCV 4 compatibility formula remains unchanged. Sources and matching contrib
are pinned by SHA-256; the build/cache/output name is `opencv5`.

```sh
NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=arm64 ./apo update opencv5
NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=x86_64 ./apo update opencv5
```

Supported formula types match `opencv`: osx (macos CLI alias), ios, catos, xros,
tvos, vs, msys2, android, emscripten and linux. WatchOS is not advertised by the
original formula and is not added here.

The platform build lists select `opencv5` wherever they select `opencv`. Linux
selects it in the separate modular workflow. `FORMULAS_OVERRIDE` remains an exact
selection. Core archives exclude `opencv5`; individual packaging includes it.
Apple packaging uses the existing XCFramework staging step.

The formula builds static module libraries with `BUILD_opencv_world=OFF`, uses
C++17, and packages installed headers and third-party archives. Windows includes
Debug and Release libraries. The output lives under `out/opencv5`, independently
of `out/opencv`. This does not imply source or ABI compatibility with ofxOpenCv.

MSVC builds skip the vendored MLAS GNU assembly kernels and keep DNN enabled
with OpenCV's built-in SGEMM fallback. MLAS acceleration is unavailable there;
inference performance may differ from platforms that build those kernels.

Validation results are recorded when available; native builds for the remaining
platforms require their respective toolchains and CI runners.
