#!/usr/bin/env bash
# Generate ofxOQS from packages and install it as a private OF addon.
# Usage: install-ofx-addon.sh PACKAGE_DIR OF_ROOT [TYPE]
set -euo pipefail
PACKAGE_DIR=${1:?Usage: install-ofx-addon.sh PACKAGE_DIR OF_ROOT [TYPE]}
OF_ROOT=${2:?OF_ROOT is required}
TYPE=${3:-osx}
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DEST="$OF_ROOT/addons/ofxOQS"
bash "$ROOT/scripts/tests/oqs/generate-ofx-addon.sh" "$PACKAGE_DIR" "$DEST" "$TYPE"
bash "$ROOT/scripts/tests/oqs/test-ofx-addon.sh" "$DEST" "$OF_ROOT"
