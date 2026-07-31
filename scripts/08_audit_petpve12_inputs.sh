#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"
SPM_WORK="$WORK/spm"
SPM12_DIR="/home/andraderenew/Downloads/spm12"
PETPVE12_DIR="$SPM12_DIR/toolbox/petpve12"
MATLAB_BIN="/usr/local/bin/matlab"
REPORT="$WORK/petpve12_input_audit.txt"

PET="$SPM_WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
GM="$SPM_WORK/rc1${SUBJECT}_T1w.nii"
WM="$SPM_WORK/rc2${SUBJECT}_T1w.nii"
CSF="$SPM_WORK/rc3${SUBJECT}_T1w.nii"
T1="$SPM_WORK/${SUBJECT}_T1w.nii"
DK_ATLAS="$PETPVE12_DIR/Atlases/Desikan-Killiany_MNI_SPM12.nii"
DK_DESC="$PETPVE12_DIR/Atlases/Desikan-Killiany_MNI_SPM12.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for path in \
    "$MATLAB_BIN" \
    "$SPM12_DIR/spm.m" \
    "$PETPVE12_DIR/spm_petpve12.m" \
    "$PETPVE12_DIR/Functions/geg_PVEcorrection.m" \
    "$PETPVE12_DIR/Config/geg_petpve12_spatial.m" \
    "$DK_ATLAS" \
    "$DK_DESC" \
    "$PET" \
    "$GM" \
    "$WM" \
    "$CSF" \
    "$T1"
do
    [[ -e "$path" ]] || die "missing required path: $path"
done

python3 - <<'PY'
import importlib
missing = []
for name in ("nibabel", "numpy", "pandas", "matplotlib"):
    try:
        importlib.import_module(name)
    except Exception:
        missing.append(name)

if missing:
    raise SystemExit(
        "ERROR: missing Python packages: "
        + ", ".join(missing)
        + "\nRun: python -m pip install nibabel numpy pandas matplotlib"
    )
PY

mkdir -p "$WORK"

{
    echo "=== PETPVE12 CONTROLLED INPUT AUDIT ==="
    echo "Date: $(date -Is)"
    echo "Subject: $SUBJECT"
    echo
    echo "=== SOFTWARE ==="
    "$MATLAB_BIN" -batch "disp(version); disp(ver('images'))" 2>/dev/null || true
    echo "SPM12: $SPM12_DIR"
    echo "PETPVE12: $PETPVE12_DIR"
    echo
    echo "=== REQUIRED INPUTS ==="
    ls -lh "$PET" "$GM" "$WM" "$CSF" "$T1" "$DK_ATLAS" "$DK_DESC"
    echo
    echo "=== PETPVE12 CONFIGURATION TAGS ==="
    grep -nE \
        "PVEcorrection.tag|PET_data.tag|SegImgs.tag|PSF.tag|gmthresh.tag|CSFsignal.tag|TissConv.tag|PVE_Const_opts.tag|wmcsfthresh" \
        "$PETPVE12_DIR/Config/geg_petpve12_spatial.m" \
        || true
    echo
    echo "=== CEREBELLAR CORTEX LABELS ==="
    grep -E "Cerebellum-Cortex" "$DK_DESC" || true
    echo
    echo "=== IMAGE GRID AND NUMERIC AUDIT ==="
    python3 - "$PET" "$GM" "$WM" "$CSF" <<'PY'
import sys
from pathlib import Path

import nibabel as nib
import numpy as np

paths = [Path(value) for value in sys.argv[1:]]
reference = nib.load(str(paths[0]))

print("Reference affine:")
print(reference.affine)

for path in paths:
    image = nib.load(str(path))
    data = np.asarray(image.dataobj, dtype=np.float32)
    finite = data[np.isfinite(data)]

    print()
    print(path.name)
    print("  shape:", image.shape)
    print("  zooms:", image.header.get_zooms()[:3])
    print("  dtype:", image.get_data_dtype())
    print("  finite fraction:", float(np.isfinite(data).mean()))
    print("  minimum:", float(finite.min()))
    print("  maximum:", float(finite.max()))
    print("  mean:", float(finite.mean()))

    if image.shape != reference.shape:
        raise SystemExit(f"ERROR: shape mismatch for {path}")
    if not np.allclose(image.affine, reference.affine, atol=1e-4):
        raise SystemExit(f"ERROR: affine mismatch for {path}")

gm = np.asarray(nib.load(str(paths[1])).dataobj, dtype=np.float32)
wm = np.asarray(nib.load(str(paths[2])).dataobj, dtype=np.float32)
csf = np.asarray(nib.load(str(paths[3])).dataobj, dtype=np.float32)

tissue_sum = gm + wm + csf
print()
print("Tissue sum percentiles:", np.percentile(tissue_sum[np.isfinite(tissue_sum)], [0, 1, 25, 50, 75, 99, 100]))
print("GM voxels >= 0.5:", int(np.count_nonzero(gm >= 0.5)))
print("WM voxels >= 0.9:", int(np.count_nonzero(wm >= 0.9)))
print("CSF voxels >= 0.9:", int(np.count_nonzero(csf >= 0.9)))

if np.count_nonzero(gm >= 0.5) < 1000:
    raise SystemExit("ERROR: too few GM voxels above 0.5")
if np.count_nonzero(wm >= 0.9) < 100:
    raise SystemExit("ERROR: too few WM voxels above 0.9")
if np.count_nonzero(csf >= 0.9) < 10:
    raise SystemExit("ERROR: too few CSF voxels above 0.9")
PY
    echo
    echo "=== PSF POLICY ==="
    echo "Nominal protocol-aligned isotropic FWHM: 5 mm."
    echo "Sensitivity values: 4, 6 and 8 mm."
    echo "The 5 mm value follows the published post-filter, not a measured effective scanner PSF."
    echo "All four outputs must be reported as a sensitivity analysis."
} | tee "$REPORT"

echo
echo "AUDIT COMPLETE"
echo "Report:"
echo "  $REPORT"
