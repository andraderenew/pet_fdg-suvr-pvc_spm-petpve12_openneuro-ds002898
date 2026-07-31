#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
RESULTS="$PROJECT_ROOT/work/$SUBJECT/results"
OUTPUT="$RESULTS/qc_suvr_complete_contact_sheet.png"
DOWNLOAD_COPY="$HOME/Downloads/qc_suvr_complete_contact_sheet.png"
TEXT_REPORT="$RESULTS/qc_suvr_numeric_review.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for path in \
    "$RESULTS/qc_suvr_psf_contact_sheet.png" \
    "$RESULTS/qc_roi_raw_vs_pvc5.png" \
    "$RESULTS/qc_roi_psf_sensitivity.png" \
    "$RESULTS/reference_values.tsv" \
    "$RESULTS/psf_sensitivity.tsv"
do
    [[ -s "$path" ]] || die "missing required file: $path"
done

python3 - <<'PY'
import importlib
missing = []
for name in ("matplotlib", "pandas"):
    try:
        importlib.import_module(name)
    except Exception:
        missing.append(name)

if missing:
    raise SystemExit(
        "ERROR: missing Python packages: "
        + ", ".join(missing)
        + "\nRun: python -m pip install matplotlib pandas"
    )
PY

python3 - "$RESULTS" "$OUTPUT" "$TEXT_REPORT" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

import matplotlib.image as mpimg
import matplotlib.pyplot as plt
import pandas as pd

results = Path(sys.argv[1])
output = Path(sys.argv[2])
text_report = Path(sys.argv[3])

images = [
    (
        results / "qc_suvr_psf_contact_sheet.png",
        "SUVR images and PSF difference",
    ),
    (
        results / "qc_roi_raw_vs_pvc5.png",
        "ROI comparison: raw vs nominal PVC",
    ),
    (
        results / "qc_roi_psf_sensitivity.png",
        "ROI PSF sensitivity",
    ),
]

reference = pd.read_csv(results / "reference_values.tsv", sep="\t")
sensitivity = pd.read_csv(results / "psf_sensitivity.tsv", sep="\t")

non_reference = sensitivity[
    (sensitivity["is_reference_label"] == 0)
    & sensitivity["cv_percent"].notna()
].copy()

top = non_reference.sort_values("cv_percent", ascending=False).head(15)

lines = [
    "OpenNeuro ds002898 sub-01 SUVR/PVC numeric review",
    "",
    "Reference values:",
]

for _, row in reference.iterrows():
    label = (
        "raw"
        if row["image"] == "raw"
        else f"PVC PSF {int(row['psf_mm'])} mm"
    )
    lines.append(
        f"  {label}: {float(row['reference_value']):.6f}"
    )

lines.extend(
    [
        "",
        f"Valid non-reference ROI rows: {len(non_reference)}",
        (
            "Median PSF CV (%): "
            f"{float(non_reference['cv_percent'].median()):.6f}"
        ),
        (
            "Maximum PSF CV (%): "
            f"{float(non_reference['cv_percent'].max()):.6f}"
        ),
        "",
        "Top 15 regions by PSF coefficient of variation:",
    ]
)

for _, row in top.iterrows():
    lines.append(
        "  "
        + str(row["region"])
        + ": CV="
        + f"{float(row['cv_percent']):.4f}%"
        + ", range="
        + f"{float(row['range']):.6f}"
    )

text_report.write_text("\n".join(lines) + "\n", encoding="utf-8")

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
    "OpenNeuro ds002898 - sub-01 FDG PET SUVR and PSF sensitivity QC",
    fontsize=20,
)

fig.savefig(output, dpi=170, bbox_inches="tight")
plt.close(fig)

print("\n".join(lines))
print()
print("QC contact sheet:")
print(f"  {output}")
PY

cp -f "$OUTPUT" "$DOWNLOAD_COPY"

echo
echo "=== REVIEW FILES ==="
ls -lh "$OUTPUT" "$DOWNLOAD_COPY" "$TEXT_REPORT"

if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$DOWNLOAD_COPY" >/dev/null 2>&1 || true
fi

echo
echo "Upload this image before running report or validate:"
echo "  $DOWNLOAD_COPY"
