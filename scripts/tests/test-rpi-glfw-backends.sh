#!/usr/bin/env bash
# Validate the produced target archive, not just its CMake options.
set -euo pipefail
: "${ARCH:?}" "${TOOLCHAIN_PREFIX:?}" "${SYSROOT:?}"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GLFW_ROOT="${OUTPUT_FOLDER:-$ROOT/out}/glfw"
archive="$GLFW_ROOT/lib/linux/$ARCH/libglfw3.a"
[ -f "$archive" ]
NM="${NM:-${TOOLCHAIN_PREFIX}-nm}"
for symbol in glfwGetX11Display glfwGetX11Window glfwGetWaylandDisplay glfwGetWaylandWindow glfwGetGLXContext glfwGetGLXWindow; do
    "$NM" --defined-only "$archive" | awk -v symbol="$symbol" '$2 == "T" && $3 == symbol { found=1 } END { exit !found }'
done
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cat > "$fixture/native.c" <<'SRC'
#define GLFW_INCLUDE_NONE
#define GLFW_EXPOSE_NATIVE_X11
#define GLFW_EXPOSE_NATIVE_WAYLAND
#define GLFW_EXPOSE_NATIVE_GLX
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>
int main(void) {
    void *volatile symbols[] = {
        (void *)glfwGetX11Display, (void *)glfwGetX11Window,
        (void *)glfwGetWaylandDisplay, (void *)glfwGetWaylandWindow,
        (void *)glfwGetGLXContext, (void *)glfwGetGLXWindow
    };
    return symbols[0] == 0;
}
SRC
"${CC:-${TOOLCHAIN_PREFIX}-gcc-10}" --sysroot="$SYSROOT" -I"$GLFW_ROOT/include" \
    "$fixture/native.c" "$archive" -o "$fixture/native" -ldl -lpthread -lm
# This checks symbol definitions and target linking. Opening a window requires
# a running compositor/display server on an actual Raspberry Pi.
echo "GLFW X11, Wayland and GLX native APIs defined and linked for $ARCH"
