#!/usr/bin/env bash
set -euo pipefail

SUBJECT="sub-01"
WORK="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/work/$SUBJECT"
REPORT="$WORK/qc_contact_sheet_sub-01.png"
TEXT_REPORT="$WORK/qc_motion_readable_sub-01.txt"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v python3 >/dev/null 2>&1 || die "python3 not found"

[[ -s "$WORK/motion_summary.json" ]] || die "motion_summary.json is missing"

python3 - "$WORK" "$REPORT" "$TEXT_REPORT" <<'PY'
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.image as mpimg

work = Path(sys.argv[1])
report = Path(sys.argv[2])
text_report = Path(sys.argv[3])

summary = json.loads((work / "motion_summary.json").read_text(encoding="utf-8"))

abs_rot_rad = summary["maximum_absolute_rotation_radians"]
abs_trans_mm = summary["maximum_absolute_translation_mm"]
rel_rot_rad = summary["maximum_frame_to_frame_rotation_radians"]
rel_trans_mm = summary["maximum_frame_to_frame_translation_mm"]

abs_rot_deg = [math.degrees(value) for value in abs_rot_rad]
rel_rot_deg = [math.degrees(value) for value in rel_rot_rad]

lines = [
    "OpenNeuro ds002898 — sub-01 motion QC",
    "",
    f"Frames: {summary['frame_count']}",
    "",
    "Maximum absolute rotation (degrees):",
    "  x={:.3f}, y={:.3f}, z={:.3f}".format(*abs_rot_deg),
    "Maximum absolute translation (mm):",
    "  x={:.3f}, y={:.3f}, z={:.3f}".format(*abs_trans_mm),
    "",
    "Maximum frame-to-frame rotation (degrees):",
    "  x={:.3f}, y={:.3f}, z={:.3f}".format(*rel_rot_deg),
    "Maximum frame-to-frame translation (mm):",
    "  x={:.3f}, y={:.3f}, z={:.3f}".format(*rel_trans_mm),
    "",
    "No automatic pass/fail decision is applied.",
    "Inspect the motion plots and all anatomical planes before continuing.",
]
text_report.write_text("\n".join(lines) + "\n", encoding="utf-8")

images = [
    ("qc_motion_translations.png", "Translations"),
    ("qc_motion_rotations.png", "Rotations"),
    ("qc_raw_mean_native_plane-1.png", "Raw mean — plane 1"),
    ("qc_raw_mean_native_plane-2.png", "Raw mean — plane 2"),
    ("qc_raw_mean_native_plane-3.png", "Raw mean — plane 3"),
    ("qc_moco_mean_2p8mm_plane-1.png", "MCFLIRT mean — plane 1"),
    ("qc_moco_mean_2p8mm_plane-2.png", "MCFLIRT mean — plane 2"),
    ("qc_moco_mean_2p8mm_plane-3.png", "MCFLIRT mean — plane 3"),
]

for filename, _ in images:
    path = work / filename
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: missing QC image: {path}")

fig, axes = plt.subplots(2, 4, figsize=(20, 10))
for ax, (filename, title) in zip(axes.flat, images):
    ax.imshow(mpimg.imread(work / filename))
    ax.set_title(title)
    ax.axis("off")

fig.suptitle(
    "OpenNeuro ds002898 — sub-01 FDG PET QC\n"
    + "Abs trans max: {:.2f} mm | Abs rot max: {:.2f}° | "
      "Frame-to-frame trans max: {:.2f} mm | Frame-to-frame rot max: {:.2f}°".format(
          max(abs_trans_mm),
          max(abs_rot_deg),
          max(rel_trans_mm),
          max(rel_rot_deg),
      ),
    fontsize=16,
)

plt.tight_layout(rect=(0, 0, 1, 0.94))
fig.savefig(report, dpi=160, bbox_inches="tight")
plt.close(fig)

print("\n".join(lines))
print()
print("QC contact sheet:")
print(f"  {report}")
print("Readable motion report:")
print(f"  {text_report}")
PY

echo
echo "=== QC FILES CREATED ==="
ls -lh "$REPORT" "$TEXT_REPORT"

if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$REPORT" >/dev/null 2>&1 || true
fi

echo
echo "Open this image and inspect it:"
echo "  $REPORT"
echo
echo "Upload the contact sheet to the chat before running SPM or PETPVE12."
