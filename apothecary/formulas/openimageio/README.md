# OpenImageIO dependencies and starter

The first dependency pass adds opt-in static `imath` 3.2.3, `openexr` 3.5.3,
`libjpeg-turbo` 3.2.1 and `libtiff` 4.7.2 formulas. They are ordinary library
formulas with explicit `FORMULA_DEPENDS`; `_depends` remains for host build tools.
They are not selected by core builds or scheduled for automatic publication.

```sh
NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=arm64 ./apo update imath openexr libjpeg-turbo libtiff
```

The dependency graph is:

- `openexr` → `imath`
- `libjpeg-turbo` → `zlib`
- `libtiff` → `zlib`, `libjpeg-turbo`

OpenEXR uses the deflate, zstd and OpenJPH sources shipped in its verified
archive, with their license notices. It requires the staged Imath rather than
fetching a replacement. TIFF includes built-in codecs, Deflate and JPEG;
optional JBIG, LERC, LZMA, zstd and WebP codecs are disabled. TurboJPEG uses
Apothecary zlib to avoid symbol collisions with TIFF's zlib dependency; its
libspng code remains bundled. SIMD follows libjpeg-turbo's platform detection,
with an explicit scalar fallback for ARM64EC.

Builds retain upstream archive names (without Imath/OpenEXR version suffixes),
installed headers and CMake exports. Libraries and CMake packages install into
`lib/<type>/<platform>` directly, so CMake generates the appropriate relative
prefix depth. JPEG's static package also exposes the conventional JPEG and
TurboJPEG target names. TIFF's config imports its static dependencies and
exposes the relocated include directory.

## Native consumer check

macOS ARM64 builds have passed this check from both the original output and a
relocated output directory containing spaces:

```sh
cmake -S scripts/tests/image-dependencies -B /tmp/image-dependency-smoke \
  -DDEPS_ROOT="$PWD/out" -DTYPE=osx -DPLATFORM=MAC_ARM64
cmake --build /tmp/image-dependency-smoke --parallel 4
ctest --test-dir /tmp/image-dependency-smoke --no-tests=error --output-on-failure
```

It links the staged CMake exports and tests Imath half conversion, TurboJPEG
encoding with classic libjpeg decoding, TIFF Deflate/JPEG, and EXR
ZIP/ZSTD/HTJ2K lossless pixel round-trips. Linux and Visual Studio branches are
provided but have not been tested with native toolchains. OpenEXR explicitly
rejects ARM64EC pending validation of its vendored SIMD kernels. Mobile targets and
XCFramework publication are not advertised in this first pass.

## OpenImageIO starter

`openimageio` pins 3.2.2.0 and declares the above formulas plus existing zlib,
libpng and fmt. It is a starter, not a completed standalone package: OpenColorIO
and robin-map formulas are still needed. To experiment before those are added,
provide an explicit installation prefix containing OpenColorIO >= 2.3 and
robin-map >= 1.3:

```sh
OPENIMAGEIO_EXTRA_PREFIX=/absolute/path/to/extra-dependencies \
  NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=arm64 ./apo update openimageio
```

The starter disables all upstream dependency downloads, tools, Python, Qt,
documentation, optional external codecs and explicit SIMD. Plugins are embedded
in the static library. The existing staged fmt headers are adapted to the
upstream header-only CMake target and internalized into OpenImageIO's install.
No remote binary cache is used for these new formulas yet.

OpenImageIO itself has not been compiled or tested. OpenColorIO's dependency
formulas, robin-map, static consumer export validation, and CI/package publication
remain the next stage; a supplied external dependency prefix is not tracked by
Apothecary's dependency cache.
