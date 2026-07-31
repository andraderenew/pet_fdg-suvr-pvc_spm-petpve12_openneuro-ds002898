#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
DATASET="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/openneuro-ds002898"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"
SPM_WORK="$WORK/spm"
SPM12_DIR="/home/andraderenew/Downloads/spm12"
MATLAB_BIN="/usr/local/bin/matlab"

T1_GZ="$DATASET/$SUBJECT/anat/${SUBJECT}_T1w.nii.gz"
PET_GZ="$WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii.gz"

T1_NII="$SPM_WORK/${SUBJECT}_T1w.nii"
PET_NII="$SPM_WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATLAB_FUNCTION="$SCRIPT_DIR/spm_segment_and_coregister_sub01.m"
QC_SCRIPT="$SCRIPT_DIR/build_spm_coreg_qc_sub01.py"
MATLAB_LOG="$HOME/Downloads/ds002898_${SUBJECT}_spm_segment_coreg_v2_$(date +%Y%m%d_%H%M%S).log"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -x "$MATLAB_BIN" ]] || die "MATLAB not found: $MATLAB_BIN"
[[ -f "$SPM12_DIR/spm.m" ]] || die "SPM12 not found: $SPM12_DIR/spm.m"
[[ -s "$T1_GZ" ]] || die "T1 not found: $T1_GZ"
[[ -s "$PET_GZ" ]] || die "static PET not found: $PET_GZ"
[[ -s "$MATLAB_FUNCTION" ]] || die "MATLAB function missing: $MATLAB_FUNCTION"
[[ -s "$QC_SCRIPT" ]] || die "QC script missing: $QC_SCRIPT"

python3 - <<'PY'
import importlib
missing = []
for name in ("nibabel", "numpy", "matplotlib"):
    try:
        importlib.import_module(name)
    except Exception:
        missing.append(name)
if missing:
    raise SystemExit(
        "ERROR: missing Python packages: "
        + ", ".join(missing)
        + "\nRun: python -m pip install nibabel numpy matplotlib"
    )
PY

mkdir -p "$SPM_WORK"

echo "=== PREPARING UNCOMPRESSED NIFTI FILES FOR SPM ==="

if [[ ! -s "$T1_NII" ]]; then
    gzip -dc "$T1_GZ" > "${T1_NII}.partial"
    mv "${T1_NII}.partial" "$T1_NII"
fi

if [[ ! -s "$PET_NII" ]]; then
    gzip -dc "$PET_GZ" > "${PET_NII}.partial"
    mv "${PET_NII}.partial" "$PET_NII"
fi

ls -lh "$T1_NII" "$PET_NII"

echo
echo "=== CHECKING MATLAB ENTRY FILE IS ASCII ==="

python3 - "$MATLAB_FUNCTION" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()

bad = [(index, value) for index, value in enumerate(data) if value > 127]
if bad:
    raise SystemExit(f"ERROR: non-ASCII bytes found in {path}: {bad[:10]}")

text = data.decode("ascii")
if not text.startswith("function spm_segment_and_coregister_sub01"):
    raise SystemExit("ERROR: MATLAB function declaration is invalid")

print("ASCII check: OK")
print("MATLAB function:", path)
PY

echo
echo "=== RUNNING SPM12 SEGMENTATION AND COREGISTRATION ==="

"$MATLAB_BIN" -batch \
  "addpath('$SCRIPT_DIR'); spm_segment_and_coregister_sub01" \
  2>&1 | tee "$MATLAB_LOG"

echo
echo "=== BUILDING COREGISTRATION QC ==="

python3 "$QC_SCRIPT"

echo
echo "=== OUTPUT CHECK ==="

for path in \
    "$SPM_WORK/rm${SUBJECT}_T1w.nii" \
    "$SPM_WORK/rc1${SUBJECT}_T1w.nii" \
    "$SPM_WORK/rc2${SUBJECT}_T1w.nii" \
    "$SPM_WORK/rc3${SUBJECT}_T1w.nii" \
    "$SPM_WORK/qc_spm_coreg_sagittal.png" \
    "$SPM_WORK/qc_spm_coreg_coronal.png" \
    "$SPM_WORK/qc_spm_coreg_axial.png" \
    "$SPM_WORK/spm_segment_coreg_summary.json"
do
    [[ -s "$path" ]] || die "missing output: $path"
    ls -lh "$path"
done

echo
echo "=== COMPLETE ==="
echo "SPM segmentation and T1-to-PET coregistration completed."
echo
echo "Upload these three QC images before PETPVE12:"
echo "  $SPM_WORK/qc_spm_coreg_sagittal.png"
echo "  $SPM_WORK/qc_spm_coreg_coronal.png"
echo "  $SPM_WORK/qc_spm_coreg_axial.png"
echo
echo "MATLAB log:"
echo "  $MATLAB_LOG"
