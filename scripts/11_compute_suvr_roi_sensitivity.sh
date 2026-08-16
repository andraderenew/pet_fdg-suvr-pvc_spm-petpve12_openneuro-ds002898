#!/usr/bin/env bash
set -euo pipefail

SPM12_DIR="${SPM12_DIR:-}"
if [[ -z "$SPM12_DIR" ]]; then
    echo "ERROR: set SPM12_DIR to the SPM12 installation directory" >&2
    exit 1
fi
export SPM12_DIR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/compute_suvr_roi_sensitivity.py"

[[ -s "$PYTHON_SCRIPT" ]] || {
    echo "ERROR: missing $PYTHON_SCRIPT" >&2
    exit 1
}

python3 "$PYTHON_SCRIPT"
