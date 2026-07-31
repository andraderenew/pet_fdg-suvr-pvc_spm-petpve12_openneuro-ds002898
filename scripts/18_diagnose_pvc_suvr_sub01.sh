#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/diagnose_pvc_suvr_sub01.py"

[[ -s "$PYTHON_SCRIPT" ]] || {
    echo "ERROR: falta $PYTHON_SCRIPT" >&2
    exit 1
}

python3 - <<'PY'
import importlib

missing = []
for name in ("nibabel", "numpy", "pandas", "matplotlib", "PIL"):
    try:
        importlib.import_module(name)
    except Exception:
        missing.append(name)

if missing:
    raise SystemExit(
        "ERROR: faltan paquetes Python: "
        + ", ".join(missing)
        + "\nEjecuta: python -m pip install nibabel numpy pandas matplotlib pillow"
    )
PY

python3 "$PYTHON_SCRIPT"
