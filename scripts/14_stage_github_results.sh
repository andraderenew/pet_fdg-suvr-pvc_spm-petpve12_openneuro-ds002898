#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${PET_PROJECT_ROOT:-$REPO_ROOT}"
export PET_PROJECT_ROOT="$PROJECT_ROOT"
SPM12_DIR="${SPM12_DIR:-}"

MODE="${1:-stage}"
SUBJECT="sub-01"
REPO="$REPO_ROOT"
WORK="$PROJECT_ROOT/work/$SUBJECT"
RESULTS="$WORK/results"
ATLAS="$WORK/atlas"
SPM_WORK="$WORK/spm"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -d "$REPO/.git" ]] || die "local GitHub repository not found: $REPO"
[[ -s "$WORK/final_validation.txt" ]] || die "run validation before GitHub staging"
grep -q "VALIDATION PASSED" "$WORK/final_validation.txt" || \
    die "final validation has not passed"

mkdir -p \
    "$REPO/scripts" \
    "$REPO/docs" \
    "$REPO/results/figures" \
    "$REPO/results/tables" \
    "$REPO/results/summaries"

echo "=== COPYING PUBLIC TABLES ==="

for path in \
    "$RESULTS/reference_values.tsv" \
    "$RESULTS/roi_summary.tsv" \
    "$RESULTS/psf_sensitivity.tsv" \
    "$RESULTS/diagnostic_primary_gray_roi.tsv" \
    "$RESULTS/diagnostic_primary_gray_psf_sensitivity.tsv" \
    "$RESULTS/diagnostic_primary_gray_psf_decomposition.tsv" \
    "$RESULTS/robust_primary_gray_psf_summary.tsv"
do
    cp -f "$path" "$REPO/results/tables/"
done

echo "=== COPYING PUBLIC SUMMARIES ==="

for path in \
    "$RESULTS/suvr_roi_summary.json" \
    "$RESULTS/pvc_suvr_diagnostic.json" \
    "$ATLAS/dk_reference_summary.json" \
    "$WORK/motion_summary.json"
do
    cp -f "$path" "$REPO/results/summaries/"
done

echo "=== SANITIZING PUBLIC JSON PATH METADATA ==="

python3 "$SCRIPT_DIR/sanitize_public_json_paths.py" \
    "$REPO/results/summaries"

echo "=== COPYING PUBLIC QC FIGURES ==="

for path in \
    "$WORK/qc_contact_sheet_sub-01.png" \
    "$SPM_WORK/qc_spm_coreg_sagittal.png" \
    "$SPM_WORK/qc_spm_coreg_coronal.png" \
    "$SPM_WORK/qc_spm_coreg_axial.png" \
    "$SPM_WORK/qc_spm_coreg_3plane.png" \
    "$ATLAS/qc_dk_atlas_reference_contact_sheet.png" \
    "$RESULTS/qc_suvr_psf_contact_sheet.png" \
    "$RESULTS/qc_roi_raw_vs_pvc5.png" \
    "$RESULTS/qc_roi_psf_sensitivity.png" \
    "$RESULTS/qc_pvc_suvr_robust_diagnostic.png" \
    "$RESULTS/qc_roi_psf_sensitivity_robust_primary_gray.png"
do
    [[ -s "$path" ]] || die "missing public figure: $path"
    cp -f "$path" "$REPO/results/figures/"
done

echo "=== SAFETY CHECK: NO NIFTI FILES IN PUBLIC PATHS ==="

if find "$REPO/scripts" "$REPO/docs" "$REPO/results" \
    -type f \( -iname '*.nii' -o -iname '*.nii.gz' \) \
    | grep -q .
then
    find "$REPO/scripts" "$REPO/docs" "$REPO/results" \
        -type f \( -iname '*.nii' -o -iname '*.nii.gz' \) -print
    die "NIfTI file detected in public staging paths"
fi

cd "$REPO"
git status --short

if [[ "$MODE" != "stage" ]]; then
    die "only safe local staging mode is supported; direct push is disabled"
fi

echo
echo "Local public-output staging complete."
echo "No commit or push was performed."
echo "Inspect git status and diff before creating a pull request."
