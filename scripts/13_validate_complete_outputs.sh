#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${PET_PROJECT_ROOT:-$REPO_ROOT}"
export PET_PROJECT_ROOT="$PROJECT_ROOT"
SPM12_DIR="${SPM12_DIR:-}"

SUBJECT="sub-01"
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
    "$RESULTS/diagnostic_primary_gray_psf_decomposition.tsv"
    "$RESULTS/robust_primary_gray_psf_summary.tsv"
    "$RESULTS/qc_roi_psf_sensitivity_robust_primary_gray.png"
    "$WORK/spm/qc_spm_coreg_3plane.png"
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

decomposition = pd.read_csv(
    results / "diagnostic_primary_gray_psf_decomposition.tsv",
    sep="\t",
)
robust_summary = pd.read_csv(
    results / "robust_primary_gray_psf_summary.tsv",
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

if len(decomposition) != 84:
    raise SystemExit("ERROR: expected 84 predefined primary gray ROIs")

if int(decomposition["low_gm_support_lt20"].sum()) != 3:
    raise SystemExit("ERROR: expected exactly three low-GM-support primary ROIs")

robust = decomposition[
    decomposition["robust_primary_gm20"] == 1
].copy()

if len(robust) != 81:
    raise SystemExit("ERROR: expected 81 robust primary gray ROIs")

robust_numeric_columns = [
    "suvr_cv_percent",
    "pvc_psf4_mean",
    "pvc_psf5_mean",
    "pvc_psf6_mean",
    "pvc_psf8_mean",
    "pvc_activity_cv_percent",
]

if not np.all(
    np.isfinite(
        robust[robust_numeric_columns].to_numpy(dtype=float)
    )
):
    raise SystemExit(
        "ERROR: incomplete/non-finite robust four-PSF data"
    )

if np.any(robust["suvr_cv_percent"] > 10.0):
    raise SystemExit("ERROR: robust primary ROI with SUVR PSF CV above 10%")

if np.any(robust["pvc_activity_cv_percent"] > 10.0):
    raise SystemExit("ERROR: robust primary ROI with PVC-activity PSF CV above 10%")

expected = {
    "suvr_median": 1.4366986814905816,
    "suvr_max": 6.037496750311221,
    "pvc_median": 3.0289178454729178,
    "pvc_max": 8.58715489301545,
}

observed = {
    "suvr_median": float(robust["suvr_cv_percent"].median()),
    "suvr_max": float(robust["suvr_cv_percent"].max()),
    "pvc_median": float(robust["pvc_activity_cv_percent"].median()),
    "pvc_max": float(robust["pvc_activity_cv_percent"].max()),
}

for key in expected:
    if not np.isclose(
        observed[key],
        expected[key],
        rtol=0.0,
        atol=1e-10,
    ):
        raise SystemExit(
            f"ERROR: robust metric drift for {key}: "
            f"{observed[key]} vs {expected[key]}"
        )

if len(robust_summary) != 2:
    raise SystemExit("ERROR: robust PSF summary must contain two populations")

robust_row = robust_summary[
    robust_summary["population"] == "robust_primary_gray_gm20"
]

if len(robust_row) != 1:
    raise SystemExit("ERROR: robust summary population missing")

if int(robust_row.iloc[0]["n_rois"]) != 81:
    raise SystemExit("ERROR: robust summary n_rois is not 81")

print("Robust primary-gray PSF validation: OK")

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
