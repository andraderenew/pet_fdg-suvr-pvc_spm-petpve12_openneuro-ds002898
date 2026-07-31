#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"
SPM_WORK="$WORK/spm"
PVC_ROOT="$WORK/petpve12"
SPM12_DIR="/home/andraderenew/Downloads/spm12"
PETPVE12_DIR="$SPM12_DIR/toolbox/petpve12"
MATLAB_BIN="/usr/local/bin/matlab"

PET="$SPM_WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
GM="$SPM_WORK/rc1${SUBJECT}_T1w.nii"
WM="$SPM_WORK/rc2${SUBJECT}_T1w.nii"
CSF="$SPM_WORK/rc3${SUBJECT}_T1w.nii"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATLAB_FUNCTION="$SCRIPT_DIR/run_petpve12_psf_sensitivity_sub01.m"
VALIDATOR="$SCRIPT_DIR/validate_petpve12_outputs.py"
LOG="$HOME/Downloads/ds002898_${SUBJECT}_petpve12_$(date +%Y%m%d_%H%M%S).log"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for path in \
    "$MATLAB_BIN" \
    "$SPM12_DIR/spm.m" \
    "$PETPVE12_DIR/Functions/geg_PVEcorrection.m" \
    "$PET" "$GM" "$WM" "$CSF" \
    "$MATLAB_FUNCTION" "$VALIDATOR"
do
    [[ -e "$path" ]] || die "missing required path: $path"
done

mkdir -p "$PVC_ROOT"

echo "=== PREPARING PSF-SPECIFIC INPUT DIRECTORIES ==="

for psf in 4 5 6 8; do
    dir="$PVC_ROOT/psf-${psf}mm"
    mkdir -p "$dir"

    cp -f "$PET" "$dir/${SUBJECT}_pet.nii"
    cp -f "$GM" "$dir/${SUBJECT}_gm.nii"
    cp -f "$WM" "$dir/${SUBJECT}_wm.nii"
    cp -f "$CSF" "$dir/${SUBJECT}_csf.nii"

    cat > "$dir/run_config.txt" <<EOF
subject=$SUBJECT
psf_fwhm_mm=$psf,$psf,$psf
gm_threshold=0.5
wm_csf_signal_threshold=0.9
csf_signal=estimated_from_csf_probability_map
save_convolved_tissues=no
method=Muller-Gartner_three_compartment
EOF
done

echo
echo "=== RUNNING PETPVE12 MG SENSITIVITY ANALYSIS ==="

"$MATLAB_BIN" -batch \
  "addpath('$SCRIPT_DIR'); run_petpve12_psf_sensitivity_sub01" \
  2>&1 | tee "$LOG"

echo
echo "=== VALIDATING AND STANDARDIZING PETPVE12 OUTPUTS ==="

python3 "$VALIDATOR"

echo
echo "=== COMPLETE ==="
echo "PETPVE12 sensitivity outputs:"
find "$PVC_ROOT" -maxdepth 2 -type f \
    \( -name '*pvcMG*.nii.gz' -o -name 'pvc*.nii' -o -name '*summary.json' \) \
    -printf '%s\t%p\n' \
    | sort -n

echo
echo "MATLAB log:"
echo "  $LOG"
