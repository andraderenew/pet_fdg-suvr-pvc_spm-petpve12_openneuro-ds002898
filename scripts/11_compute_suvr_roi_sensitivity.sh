#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/compute_suvr_roi_sensitivity.py"

[[ -s "$PYTHON_SCRIPT" ]] || {
    echo "ERROR: missing $PYTHON_SCRIPT" >&2
    exit 1
}

python3 "$PYTHON_SCRIPT"
