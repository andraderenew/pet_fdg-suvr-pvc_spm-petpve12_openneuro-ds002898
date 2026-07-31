from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

subject = "sub-01"
project_root = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
)
work = project_root / "work" / subject
results = work / "results"

motion_path = work / "motion_summary.json"
atlas_summary_path = work / "atlas" / "dk_reference_summary.json"
suvr_summary_path = results / "suvr_roi_summary.json"
diagnostic_path = results / "pvc_suvr_diagnostic.json"
primary_sensitivity_path = (
    results / "diagnostic_primary_gray_psf_sensitivity.tsv"
)

for path in (
    motion_path,
    atlas_summary_path,
    suvr_summary_path,
    diagnostic_path,
    primary_sensitivity_path,
):
    if not path.is_file():
        raise SystemExit(f"ERROR: missing report input: {path}")

motion = json.loads(motion_path.read_text(encoding="utf-8"))
atlas = json.loads(atlas_summary_path.read_text(encoding="utf-8"))
suvr = json.loads(suvr_summary_path.read_text(encoding="utf-8"))
diagnostic = json.loads(diagnostic_path.read_text(encoding="utf-8"))
primary = pd.read_csv(primary_sensitivity_path, sep="\t")

valid = primary[primary["cv_percent"].notna()].copy()
if valid.empty:
    raise SystemExit("ERROR: no valid primary gray-matter sensitivity rows")

median_cv = float(valid["cv_percent"].median())
max_cv = float(valid["cv_percent"].max())
max_row = valid.loc[valid["cv_percent"].idxmax()]

nominal_summary = next(
    item
    for item in diagnostic["image_summaries"]
    if item["image"] == "pvc_psf_5mm"
)

report = f"""# OpenNeuro ds002898 sub-01 FDG PET analysis

## Scope

This repository contains a reproducible single-subject research portfolio
demonstration using public OpenNeuro dataset `ds002898`. It is not intended
for clinical or diagnostic use.

## Data and static PET construction

- Subject: `{subject}`
- Tracer: 18F-FDG
- Source PET frames: 356
- Selected frames: 225
- Selection rule: `FrameTimesStart >= 1800 and < 5400 seconds`
- Selected starts: 1808 to 5392 seconds
- Frame duration: 16 seconds
- Static image: temporal mean after local MCFLIRT motion correction
- Processing grid: 2.8 mm isotropic, 172 x 172 x 93

## Motion quality control

- Maximum absolute translations (mm): {motion["maximum_absolute_translation_mm"]}
- Maximum absolute rotations (radians): {motion["maximum_absolute_rotation_radians"]}
- Maximum frame-to-frame translations (mm): {motion["maximum_frame_to_frame_translation_mm"]}
- Maximum frame-to-frame rotations (radians): {motion["maximum_frame_to_frame_rotation_radians"]}

Motion correction and static-PET visual QC were accepted for continuation.

## Structural processing

SPM12 was used for T1 segmentation and T1-to-PET coregistration. Native GM,
WM and CSF probability maps were resliced to the PET grid. Visual PET-T1
coregistration QC was accepted.

## Partial-volume correction

PETPVE12 Muller-Gartner three-compartment PVC was run with:

- GM threshold: 0.5
- WM/CSF signal threshold: 0.9
- CSF signal estimated from the CSF probability map
- Nominal protocol-aligned isotropic PSF: 5 mm
- Sensitivity PSFs: 4, 6 and 8 mm

The 5 mm value follows the published reconstruction post-filter. It is not
presented as a directly measured effective scanner PSF; therefore all PSF
outputs are retained and reported.

Within atlas-labeled voxels with GM probability >= 0.5, the nominal 5 mm PVC
SUVR image contained {nominal_summary["negative_percent"]:.4f}% negative
voxels. These were sparse and did not produce a negative mean in any primary
gray-matter ROI.

## SUVR reference region

The reference region is bilateral cerebellar cortex from the PETPVE12
Desikan-Killiany atlas:

- Left cerebellar cortex: label 8
- Right cerebellar cortex: label 47
- PET-space atlas voxels in bilateral cerebellar cortex: {atlas["cerebellar_atlas_voxels"]}
- Cerebellar voxels with GM probability >= 0.5: {atlas["cerebellar_gm50_voxels"]}

Raw PET reference activity was calculated as a GM-probability-weighted
cerebellar mean. PVC reference activity was calculated from positive PVC
values within cerebellar cortex and GM probability >= 0.5.

## Primary gray-matter PSF sensitivity

Primary gray-matter ROIs include cortical Desikan-Killiany labels and selected
subcortical gray-matter labels. White-matter and non-primary atlas labels are
excluded from the headline sensitivity summary.

- Valid primary gray-matter ROIs: {len(valid)}
- Median coefficient of variation across PSF assumptions: {median_cv:.3f}%
- Maximum coefficient of variation: {max_cv:.3f}%
- Region with maximum coefficient of variation: {max_row["region"]}
- Primary ROIs with CV above 10%: {diagnostic["primary_psf_cv_above_10pct_count"]}
- Primary ROIs with CV above 20%: {diagnostic["primary_psf_cv_above_20pct_count"]}
- Primary ROIs with negative nominal PVC mean: {diagnostic["primary_negative_nominal_mean_count"]}

The complete public ROI summary contains 181 data rows. Labels outside the
primary gray-matter set are not used for the headline conclusion.

## Public outputs

- `reference_values.tsv`
- `roi_summary.tsv`
- `psf_sensitivity.tsv`
- `diagnostic_primary_gray_roi.tsv`
- `diagnostic_primary_gray_psf_sensitivity.tsv`
- `pvc_suvr_diagnostic.json`
- `qc_pvc_suvr_robust_diagnostic.png`
- PET motion, coregistration, atlas-reference and SUVR QC figures

Raw OpenNeuro imaging data and intermediate NIfTI files are not intended for
commit to this repository.
"""

report_path = results / "RESULTS_SUB01.md"
report_path.write_text(report, encoding="utf-8")

methods = """# Methods

Dynamic FDG PET from OpenNeuro ds002898 was reduced to the 225 equal-duration
frames whose BIDS `FrameTimesStart` values were at least 1800 seconds and less
than 5400 seconds. Frames were resampled to a fixed 2.8 mm isotropic grid to
fit available memory, motion-corrected with FSL MCFLIRT, and averaged.

The T1-weighted MRI was segmented with SPM12. Bias-corrected T1 and GM, WM and
CSF probability maps were coregistered and resliced to the PET grid.

PETPVE12 Muller-Gartner PVC was performed with GM threshold 0.5 and WM/CSF
signal threshold 0.9. The nominal 5 mm isotropic PSF follows the published
post-reconstruction Gaussian filter. Additional 4, 6 and 8 mm assumptions
were processed as a sensitivity analysis because the effective reconstructed
scanner PSF was not directly measured in the dataset.

The PETPVE12 Desikan-Killiany atlas was inverse-warped from MNI space to the
subject T1, then coregistered and nearest-neighbour resliced to the PET grid.
Bilateral cerebellar cortex labels 8 and 47 formed the SUVR reference region.

Headline PSF-sensitivity statistics were restricted to primary cortical and
subcortical gray-matter ROIs. The full atlas output was retained as a
transparent supplementary table.
"""
methods_path = results / "METHODS_SUB01.md"
methods_path.write_text(methods, encoding="utf-8")

print(report_path)
print(methods_path)
