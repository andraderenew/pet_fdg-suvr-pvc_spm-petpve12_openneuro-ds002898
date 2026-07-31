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

- Valid primary gray-matter ROIs: 84
- Median coefficient of variation across PSF assumptions: 1.488%
- Maximum coefficient of variation: 7.116%
- Region with maximum coefficient of variation: ctx-lh-frontalpole
- Primary ROIs with CV above 10%: 0
- Primary ROIs with CV above 20%: 0
- Primary ROIs with negative nominal PVC mean: 0

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
