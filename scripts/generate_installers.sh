#!/usr/bin/env bash
# Batch-generate relocatable pkg-config + CMake files for a finished out/ tree.
# Per-formula copy already runs scripts/export_config.sh (issue #405). This
# is the same pass over every formula dest, for packaging / retrofits.

set -euo pipefail
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APOTHECARY_LEVEL="$(cd "$CURRENT_DIR/.." && pwd)"
OUT_DIR="${1:-${OUTPUT_FOLDER:-$APOTHECARY_LEVEL/out}}"
if [ ! -d "$OUT_DIR" ]; then
    echo "No out dir at $OUT_DIR"
    exit 1
fi
bash "$CURRENT_DIR/export_config.sh" --all "$OUT_DIR"
