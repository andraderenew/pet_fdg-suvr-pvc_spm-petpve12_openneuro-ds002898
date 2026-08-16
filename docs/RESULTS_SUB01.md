# OpenNeuro ds002898 sub-01 FDG PET analysis

## Scope

This repository contains a reproducible single-subject research portfolio
demonstration using public OpenNeuro dataset `ds002898`. It is not intended
for clinical or diagnostic use.

## Data and static PET construction

- Subject: `sub-01`
- Tracer: 18F-FDG
- Source PET frames: 356
- Selected frames: 225
- Selection rule: `FrameTimesStart >= 1800 and < 5400 seconds`
- Selected starts: 1808 to 5392 seconds
- Frame duration: 16 seconds
- Static image: temporal mean after local MCFLIRT motion correction
- Processing grid: 2.8 mm isotropic, 172 x 172 x 93

## Motion quality control

- Maximum absolute translations (mm): [0.955967, 0.410645, 1.51746]
- Maximum absolute rotations (radians): [0.028976, 0.0219448, 0.0162064]
- Maximum frame-to-frame translations (mm): [0.43507969999999996, 0.2033191, 0.6576380000000001]
- Maximum frame-to-frame rotations (radians): [0.0329339, 0.0081446, 0.00896977]

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
SUVR image contained 0.1624% negative
voxels. These were sparse and did not produce a negative mean in any primary
gray-matter ROI.

## SUVR reference region

The reference region is bilateral cerebellar cortex from the PETPVE12
Desikan-Killiany atlas:

- Left cerebellar cortex: label 8
- Right cerebellar cortex: label 47
- PET-space atlas voxels in bilateral cerebellar cortex: 4860
- Cerebellar voxels with GM probability >= 0.5: 4224

Raw PET reference activity was calculated as a GM-probability-weighted
cerebellar mean. PVC reference activity was calculated from positive PVC
values within cerebellar cortex and GM probability >= 0.5.

## Primary gray-matter PSF sensitivity

Primary gray-matter ROIs include cortical Desikan-Killiany labels and selected
subcortical gray-matter labels. White-matter and non-primary atlas labels are
excluded from the headline sensitivity summary.

The predefined primary-gray set contains 84 ROIs. Three have fewer than
20 voxels with GM probability >= 0.5:

- left pallidum: 1 voxel;
- right pallidum: 2 voxels;
- left frontal pole: 17 voxels.

Across all 84 predefined ROIs, the cerebellar-normalized PVC-SUVR PSF CV has
a median of 1.488% and a maximum of 7.116%. The maximum occurs in the
left frontal pole, which is one of the low-support ROIs.

Using the post hoc QA support threshold, the robustness subset contains 81 ROIs with at least 20 GM-support voxels:

- median cerebellar-normalized PVC-SUVR PSF CV: 1.437%;
- maximum cerebellar-normalized PVC-SUVR PSF CV: 6.037%;
- region with maximum robust SUVR CV: `ctx-rh-frontalpole`;
- robust ROIs with SUVR CV above 10%: 0;
- median PVC-activity PSF CV before SUVR normalization: 3.029%;
- maximum PVC-activity PSF CV before SUVR normalization: 8.587%;
- robust ROIs with PVC-activity CV above 10%: 0;
- primary ROIs with negative nominal PVC mean: 0.

The PSF-specific cerebellar reference values are 19378.662, 19659.520,
19976.926 and 20707.605 for the 4, 5, 6 and 8 mm assumptions respectively.
The reference therefore increases by 6.858% between 4 and 8 mm. Because each
PVC image is normalized by its own reference, the SUVR CV reflects both
regional PVC sensitivity and PSF-dependent normalization. The accompanying
PVC-activity CV isolates regional sensitivity before SUVR normalization.

The complete public ROI summary retains all atlas labels and all 84 predefined
primary-gray ROIs. Low-support ROIs are flagged rather than deleted.

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
