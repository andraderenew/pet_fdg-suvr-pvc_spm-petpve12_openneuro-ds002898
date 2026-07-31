#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-stage}"
SUBJECT="sub-01"
REPO="$HOME/github/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
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

echo "=== COPYING REPRODUCIBLE SCRIPTS ==="

for path in "$SCRIPT_DIR"/*; do
    case "$path" in
        *.sh|*.m|*.py)
            cp -f "$path" "$REPO/scripts/"
            ;;
    esac
done

echo "=== COPYING PUBLIC DOCUMENTATION ==="

cp -f "$RESULTS/RESULTS_SUB01.md" "$REPO/docs/"
cp -f "$RESULTS/METHODS_SUB01.md" "$REPO/docs/"

echo "=== COPYING PUBLIC TABLES ==="

for path in \
    "$RESULTS/reference_values.tsv" \
    "$RESULTS/roi_summary.tsv" \
    "$RESULTS/psf_sensitivity.tsv" \
    "$RESULTS/diagnostic_primary_gray_roi.tsv" \
    "$RESULTS/diagnostic_primary_gray_psf_sensitivity.tsv"
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

echo "=== COPYING PUBLIC QC FIGURES ==="

for path in \
    "$WORK/qc_contact_sheet_sub-01.png" \
    "$SPM_WORK/qc_spm_coreg_sagittal.png" \
    "$SPM_WORK/qc_spm_coreg_coronal.png" \
    "$SPM_WORK/qc_spm_coreg_axial.png" \
    "$ATLAS/qc_dk_atlas_reference_contact_sheet.png" \
    "$RESULTS/qc_suvr_psf_contact_sheet.png" \
    "$RESULTS/qc_roi_raw_vs_pvc5.png" \
    "$RESULTS/qc_roi_psf_sensitivity.png" \
    "$RESULTS/qc_pvc_suvr_robust_diagnostic.png"
do
    [[ -s "$path" ]] || die "missing public figure: $path"
    cp -f "$path" "$REPO/results/figures/"
done

echo "=== UPDATING README STATUS ==="

python3 - "$REPO/README.md" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

marker = "## Completed single-subject demonstration"
section = """## Completed single-subject demonstration

A quality-controlled `sub-01` demonstration has been completed using public
OpenNeuro `ds002898` data. The workflow includes dynamic-frame selection,
memory-controlled PET resampling, MCFLIRT motion correction, static FDG PET
construction, SPM12 segmentation and PET-T1 coregistration, PETPVE12
Muller-Gartner PVC, bilateral cerebellar-cortex SUVR, and a 4/5/6/8 mm PSF
sensitivity analysis.

Headline sensitivity statistics are restricted to primary cortical and
subcortical gray-matter ROIs. The full atlas table remains available for
transparency. Public tables, summaries, documentation and QC figures are
available under `results/` and `docs/`. Raw OpenNeuro data and intermediate
NIfTI derivatives are not included in the repository.

"""

if marker in text:
    before, remainder = text.split(marker, 1)
    next_header = remainder.find("\n## ", 1)
    if next_header >= 0:
        text = before + section + remainder[next_header + 1 :]
    else:
        text = before + section
else:
    insertion = text.find("\n## ")
    if insertion >= 0:
        text = text[: insertion + 1] + section + text[insertion + 1 :]
    else:
        text = text.rstrip() + "\n\n" + section

path.write_text(text.rstrip() + "\n", encoding="utf-8")
PY

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

if [[ "$MODE" == "--push" ]]; then
    git add scripts docs results README.md
    git commit -m "Complete OpenNeuro ds002898 FDG PET PVC demonstration" || true
    git push origin main

    echo
    echo "GitHub push complete."
    echo "Do not create the Zenodo release until the remote repository is inspected."
else
    echo
    echo "Files were copied into the local repository but were not committed."
    echo "Inspect:"
    echo "  cd \"$REPO\""
    echo "  git status"
    echo "  git diff -- README.md"
fi
