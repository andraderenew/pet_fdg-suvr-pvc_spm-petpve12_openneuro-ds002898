#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ROOT="${PET_PROJECT_ROOT:-$REPO_ROOT}"
export PET_PROJECT_ROOT="$PROJECT_ROOT"

SUBJECT="sub-01"
RESULTS="$PROJECT_ROOT/work/$SUBJECT/results"
OUTPUT="$RESULTS/qc_suvr_complete_contact_sheet.png"
TEXT_REPORT="$RESULTS/qc_suvr_numeric_review.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for path in \
    "$RESULTS/qc_suvr_psf_contact_sheet.png" \
    "$RESULTS/qc_roi_raw_vs_pvc5.png" \
    "$RESULTS/qc_roi_psf_sensitivity_robust_primary_gray.png" \
    "$RESULTS/robust_primary_gray_psf_summary.tsv" \
    "$RESULTS/diagnostic_primary_gray_psf_decomposition.tsv"
do
    [[ -s "$path" ]] || die "missing required file: $path"
done

python3 - "$RESULTS" "$OUTPUT" "$TEXT_REPORT" <<'PY'
from pathlib import Path
import sys

import matplotlib.image as mpimg
import matplotlib.pyplot as plt
import pandas as pd


results = Path(sys.argv[1])
output = Path(sys.argv[2])
text_report = Path(sys.argv[3])

summary = pd.read_csv(
    results / "robust_primary_gray_psf_summary.tsv",
    sep="\t",
)

decomposition = pd.read_csv(
    results
    / "diagnostic_primary_gray_psf_decomposition.tsv",
    sep="\t",
)

robust_row = summary[
    summary["population"]
    == "robust_primary_gray_gm20"
]

if len(robust_row) != 1:
    raise SystemExit(
        "ERROR: robust summary row missing"
    )

robust_row = robust_row.iloc[0]

robust = decomposition[
    decomposition["robust_primary_gm20"] == 1
].copy()

low_support = decomposition[
    decomposition["low_gm_support_lt20"] == 1
].copy()

if len(decomposition) != 84:
    raise SystemExit(
        "ERROR: expected 84 predefined primary ROIs"
    )

if len(robust) != 81:
    raise SystemExit(
        "ERROR: expected 81 robust primary ROIs"
    )

if len(low_support) != 3:
    raise SystemExit(
        "ERROR: expected three low-support ROIs"
    )

top = robust.sort_values(
    "suvr_cv_percent",
    ascending=False,
).head(12)

lines = [
    "OpenNeuro ds002898 sub-01 SUVR/PVC robust review",
    "",
    "Predefined primary gray ROIs: 84",
    "Low-support ROIs (<20 GM50 voxels): 3",
    "Robust primary gray ROIs: 81",
    "",
    (
        "Robust cerebellar-normalized PVC-SUVR "
        "PSF CV median (%): "
        f"{float(robust_row['suvr_cv_median_percent']):.6f}"
    ),
    (
        "Robust cerebellar-normalized PVC-SUVR "
        "PSF CV maximum (%): "
        f"{float(robust_row['suvr_cv_max_percent']):.6f}"
    ),
    (
        "Robust PVC-activity PSF CV median (%): "
        f"{float(robust_row['pvc_activity_cv_median_percent']):.6f}"
    ),
    (
        "Robust PVC-activity PSF CV maximum (%): "
        f"{float(robust_row['pvc_activity_cv_max_percent']):.6f}"
    ),
    "",
    "Top robust regions by normalized SUVR PSF CV:",
]

for _, row in top.iterrows():
    lines.append(
        "  "
        + str(row["region"])
        + ": SUVR CV="
        + f"{float(row['suvr_cv_percent']):.4f}%"
        + ", PVC-activity CV="
        + f"{float(row['pvc_activity_cv_percent']):.4f}%"
        + ", GM50 voxels="
        + str(int(row["gm50_voxel_count"]))
    )

lines.extend(
    [
        "",
        "Flagged low-support ROIs:",
    ]
)

for _, row in low_support.iterrows():
    lines.append(
        "  "
        + str(row["region"])
        + ": GM50 voxels="
        + str(int(row["gm50_voxel_count"]))
        + ", SUVR CV="
        + f"{float(row['suvr_cv_percent']):.4f}%"
    )

text_report.write_text(
    "\n".join(lines) + "\n",
    encoding="utf-8",
)

images = [
    (
        results / "qc_suvr_psf_contact_sheet.png",
        "SUVR images and PSF difference",
    ),
    (
        results / "qc_roi_raw_vs_pvc5.png",
        "Raw vs nominal 5 mm PVC",
    ),
    (
        results
        / "qc_roi_psf_sensitivity_robust_primary_gray.png",
        "Robust primary-gray PSF sensitivity",
    ),
]

fig = plt.figure(figsize=(18, 18))

ax1 = fig.add_axes([0.04, 0.53, 0.92, 0.42])
ax1.imshow(mpimg.imread(images[0][0]))
ax1.set_title(images[0][1], fontsize=16)
ax1.axis("off")

ax2 = fig.add_axes([0.05, 0.05, 0.42, 0.40])
ax2.imshow(mpimg.imread(images[1][0]))
ax2.set_title(images[1][1], fontsize=16)
ax2.axis("off")

ax3 = fig.add_axes([0.53, 0.05, 0.42, 0.40])
ax3.imshow(mpimg.imread(images[2][0]))
ax3.set_title(images[2][1], fontsize=16)
ax3.axis("off")

fig.suptitle(
    "OpenNeuro ds002898 - sub-01 FDG PET "
    "SUVR and robust PSF sensitivity QC",
    fontsize=20,
)

fig.savefig(
    output,
    dpi=170,
    bbox_inches="tight",
)

plt.close(fig)

print("\n".join(lines))
print()
print("QC contact sheet:")
print(f"  {output}")
PY


echo
echo "=== REVIEW FILES ==="
ls -lh "$OUTPUT" "$TEXT_REPORT"
