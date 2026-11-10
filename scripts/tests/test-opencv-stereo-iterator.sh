#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PATCH="$ROOT/apothecary/formulas/opencv/stereo-iterator.patch"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/modules/calib3d/src"
cat > "$fixture/modules/calib3d/src/stereo_geom.cpp" <<'EOF'
// This file is part of OpenCV project.
// It is subject to the license terms in the LICENSE file found in the top-level directory
// of this distribution and at http://opencv.org/license.html

#include "precomp.hpp"

namespace cv {
void reprojectImageTo3D();
}
EOF
(cd "$fixture" && patch -p1 < "$PATCH")
grep -q '^#include <iterator>' "$fixture/modules/calib3d/src/stereo_geom.cpp"
echo 'OpenCV 4.14 stereo_geom.cpp includes <iterator> after the libc++ 23 patch'
