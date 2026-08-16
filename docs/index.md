# FDG PET SUVR and PETPVE12 PVC — OpenNeuro ds002898

This repository presents a completed, quality-controlled single-subject
research workflow using public OpenNeuro dataset `ds002898`.

## Completed workflow

The `sub-01` demonstration includes:

- selection of 225 equal-duration FDG PET frames from approximately 30–90 min;
- memory-controlled resampling to a 2.8 mm isotropic processing grid;
- FSL MCFLIRT motion correction and static PET construction;
- SPM12 T1 segmentation and PET–T1 coregistration;
- PETPVE12 Müller–Gärtner partial-volume correction;
- nominal 5 mm PSF with 4, 6 and 8 mm sensitivity analyses;
- bilateral cerebellar-cortex SUVR using Desikan–Killiany labels 8 and 47;
- atlas ROI summaries, diagnostic tables and quality-control figures.

## Validated summary

- 84 predefined primary gray-matter ROIs;
- 3 predefined ROIs have GM>=0.5 support below 20 voxels;
- 81 ROIs form the post hoc QA robustness subset;
- robust cerebellar-normalized PVC-SUVR PSF CV: median 1.437%, maximum 6.037%;
- robust PVC-activity PSF CV before SUVR normalization: median 3.029%, maximum 8.587%;
- no robust primary gray-matter ROI exceeds 10% CV by either measure;
- no primary gray-matter ROI has a negative nominal PVC mean;
- PSF-specific cerebellar normalization is explicitly separated from
  pre-normalization PVC-activity sensitivity.

## Repository contents

- [`METHODS_SUB01.md`](METHODS_SUB01.md): detailed methods.
- [`RESULTS_SUB01.md`](RESULTS_SUB01.md): validated results and limitations.
- [`../results/tables/`](../results/tables/): public TSV tables.
- [`../results/summaries/`](../results/summaries/): JSON summaries.
- [`../results/figures/`](../results/figures/): motion, coregistration, atlas and SUVR QC.
- [`../scripts/`](../scripts/): reproducible Bash, Python and MATLAB scripts.

## Data policy

Raw OpenNeuro imaging data and intermediate NIfTI derivatives are not
included. The repository is a research portfolio demonstration and is not
clinical or diagnostic software.
