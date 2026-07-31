#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"
SPM_WORK="$WORK/spm"
ATLAS_WORK="$WORK/atlas"
SPM12_DIR="/home/andraderenew/Downloads/spm12"
PETPVE12_DIR="$SPM12_DIR/toolbox/petpve12"
MATLAB_BIN="/usr/local/bin/matlab"

SOURCE_T1="$SPM_WORK/${SUBJECT}_T1w.nii"
PET="$SPM_WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
GM="$SPM_WORK/rc1${SUBJECT}_T1w.nii"
COREG_T1="$SPM_WORK/rm${SUBJECT}_T1w.nii"
DK_ATLAS="$PETPVE12_DIR/Atlases/Desikan-Killiany_MNI_SPM12.nii"
DK_DESC="$PETPVE12_DIR/Atlases/Desikan-Killiany_MNI_SPM12.txt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATLAB_FUNCTION="$SCRIPT_DIR/prepare_dk_atlas_reference_sub01.m"
PYTHON_QC="$SCRIPT_DIR/build_dk_reference_masks_qc.py"
LOG="$HOME/Downloads/ds002898_${SUBJECT}_atlas_reference_$(date +%Y%m%d_%H%M%S).log"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for path in \
    "$MATLAB_BIN" "$SPM12_DIR/spm.m" \
    "$SOURCE_T1" "$PET" "$GM" "$COREG_T1" \
    "$DK_ATLAS" "$DK_DESC" \
    "$MATLAB_FUNCTION" "$PYTHON_QC"
do
    [[ -e "$path" ]] || die "missing required path: $path"
done

mkdir -p "$ATLAS_WORK"

T1_ATLASPREP="$ATLAS_WORK/${SUBJECT}_T1w_atlasprep.nii"
if [[ ! -s "$T1_ATLASPREP" ]]; then
    cp -f "$SOURCE_T1" "$T1_ATLASPREP"
fi

echo "=== PREPARING DESIKAN-KILLIANY ATLAS AND REFERENCE REGION ==="

"$MATLAB_BIN" -batch \
  "addpath('$SCRIPT_DIR'); prepare_dk_atlas_reference_sub01" \
  2>&1 | tee "$LOG"

echo
echo "=== BUILDING CEREBELLAR CORTEX MASKS AND QC ==="

python3 "$PYTHON_QC"

echo
echo "=== COMPLETE ==="
find "$ATLAS_WORK" -maxdepth 1 -type f \
    \( -name '*atlas*.nii*' -o -name '*cerebellar*.nii*' -o -name 'qc_*.png' -o -name '*summary.json' \) \
    -printf '%s\t%p\n' \
    | sort -n

echo
echo "MATLAB log:"
echo "  $LOG"
