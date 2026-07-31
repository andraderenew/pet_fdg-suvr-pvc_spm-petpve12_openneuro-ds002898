#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"
RESULTS="$WORK/results"
ATLAS="$WORK/atlas"
PVC="$WORK/petpve12"
REPORT="$WORK/final_validation.txt"

required=(
    "$WORK/motion_summary.json"
    "$WORK/qc_contact_sheet_sub-01.png"
    "$WORK/spm/qc_spm_coreg_sagittal.png"
    "$WORK/spm/qc_spm_coreg_coronal.png"
    "$WORK/spm/qc_spm_coreg_axial.png"
    "$ATLAS/qc_dk_atlas_reference_contact_sheet.png"
    "$ATLAS/dk_reference_summary.json"
    "$RESULTS/reference_values.tsv"
    "$RESULTS/roi_summary.tsv"
    "$RESULTS/psf_sensitivity.tsv"
    "$RESULTS/diagnostic_primary_gray_roi.tsv"
    "$RESULTS/diagnostic_primary_gray_psf_sensitivity.tsv"
    "$RESULTS/pvc_suvr_diagnostic.json"
    "$RESULTS/qc_pvc_suvr_robust_diagnostic.png"
    "$RESULTS/suvr_roi_summary.json"
    "$RESULTS/RESULTS_SUB01.md"
    "$RESULTS/METHODS_SUB01.md"
)

for psf in 4 5 6 8; do
    required+=(
        "$PVC/psf-${psf}mm/${SUBJECT}_desc-pvcMG_psf-${psf}mm_pet.nii.gz"
        "$PVC/psf-${psf}mm/petpve12_summary.json"
        "$RESULTS/${SUBJECT}_desc-pvcMG_psf-${psf}mm_cerebellar-cortex_suvr.nii.gz"
    )
done

{
    echo "=== FINAL VALIDATION ==="
    echo "Date: $(date -Is)"
    echo

    for path in "${required[@]}"; do
        if [[ ! -s "$path" ]]; then
            echo "MISSING: $path"
            exit 1
        fi
        echo "OK: $path"
    done

    echo
    echo "=== NUMERIC AND DIAGNOSTIC CHECKS ==="

    python3 - "$RESULTS" <<'PY'
from pathlib import Path
import json
import sys

import numpy as np
import pandas as pd

results = Path(sys.argv[1])

reference = pd.read_csv(results / "reference_values.tsv", sep="\t")
roi = pd.read_csv(results / "roi_summary.tsv", sep="\t")
primary_roi = pd.read_csv(
    results / "diagnostic_primary_gray_roi.tsv",
    sep="\t",
)
primary_sensitivity = pd.read_csv(
    results / "diagnostic_primary_gray_psf_sensitivity.tsv",
    sep="\t",
)
diagnostic = json.loads(
    (results / "pvc_suvr_diagnostic.json").read_text(encoding="utf-8")
)

print("Reference rows:", len(reference))
print("Full atlas ROI rows:", len(roi))
print("Primary gray ROI rows:", len(primary_roi))
print("Primary sensitivity rows:", len(primary_sensitivity))

if len(reference) != 5:
    raise SystemExit("ERROR: expected five reference rows")
if len(roi) < 100:
    raise SystemExit("ERROR: unexpectedly few full-atlas ROI rows")
if len(primary_roi) < 70:
    raise SystemExit("ERROR: unexpectedly few primary gray ROI rows")
if len(primary_sensitivity) < 70:
    raise SystemExit("ERROR: unexpectedly few primary sensitivity rows")
if not np.all(np.isfinite(reference["reference_value"])):
    raise SystemExit("ERROR: non-finite reference values")
if np.any(reference["reference_value"] <= 0):
    raise SystemExit("ERROR: non-positive reference value")

if diagnostic["primary_negative_nominal_mean_count"] != 0:
    raise SystemExit("ERROR: negative nominal mean in a primary gray ROI")
if diagnostic["primary_nonfinite_nominal_mean_count"] != 0:
    raise SystemExit("ERROR: non-finite nominal mean in a primary gray ROI")
if diagnostic["primary_psf_cv_above_10pct_count"] != 0:
    raise SystemExit("ERROR: primary gray ROI with PSF CV above 10%")

nominal = next(
    item
    for item in diagnostic["image_summaries"]
    if item["image"] == "pvc_psf_5mm"
)
if nominal["negative_percent"] >= 1.0:
    raise SystemExit(
        "ERROR: nominal PVC has at least 1% negative voxels in atlas GM"
    )

print("Primary gray-matter diagnostic validation: OK")
PY

    echo
    echo "=== GITHUB SAFETY POLICY ==="
    echo "Only scripts, Markdown, TSV, JSON summaries and PNG QC figures may be staged."
    echo "Raw NIfTI files and intermediate imaging derivatives must not be committed."
    echo
    echo "VALIDATION PASSED"
} | tee "$REPORT"

echo
echo "Validation report:"
echo "  $REPORT"
