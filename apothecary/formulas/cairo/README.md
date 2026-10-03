# Cairo for Emscripten

Build with `TYPE=emscripten ARCH=32 NO_COLOR=1 UI_ANIM=0 ./apo update cairo`.
This builds Cairo and its dependencies and stages `libcairo.a` in
`out/cairo/lib/emscripten/WASM`, with headers in `out/cairo/include/cairo`.

The WebAssembly package supports software image surfaces, PNG input/output,
SVG/PDF/PS output, and FreeType fonts. It has no native window-system backend
or Fontconfig font discovery. Load fonts explicitly with FreeType and
`cairo_ft_font_face_create_for_ft_face`. Applications can copy image-surface
pixels to a browser Canvas; this package does not implement a Canvas backend.

Cairo and Pixman are built without thread safety. Use them from one thread.
Apothecary's other dependencies may require `-pthread` when linking.

The Emscripten workflow runs `bash scripts/emscripten/test_cairo.sh` after
building. This links the staged archives and checks a rendered pixel plus
PNG, SVG and PDF stream output in Node.
