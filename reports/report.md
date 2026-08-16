# FDG PET PVC/SUVR audit report

## Aim

Demonstrate a reproducible single-subject FDG PET processing workflow using
OpenNeuro `ds002898`, including motion correction, PET-T1 registration,
Muller-Gartner partial-volume correction, cerebellar-cortex SUVR and explicit
PSF-sensitivity analysis.

## Data

- Subject: `sub-01`
- Tracer: 18F-FDG
- Source: 356 dynamic PET frames
- Selected interval: frame starts >=1800 and <5400 seconds
- Selected frames: 225
- Processing grid: 2.8 mm isotropic

## Processing

The workflow uses FSL MCFLIRT, SPM12, PETPVE12 and Python. PETPVE12
Muller-Gartner PVC was evaluated with nominal 5 mm PSF and 4, 6 and 8 mm
sensitivity assumptions. Bilateral Desikan-Killiany cerebellar cortex labels
8 and 47 form the SUVR reference.

## Quantitative audit

There are 84 predefined primary gray-matter ROIs. Three have fewer than
20 GM>=0.5 support voxels, leaving 81 ROIs in the post hoc QA robustness subset.

For the 81 robust ROIs:

- median cerebellar-normalized PVC-SUVR PSF CV: 1.437%;
- maximum cerebellar-normalized PVC-SUVR PSF CV: 6.037%;
- median PVC-activity PSF CV before SUVR normalization: 3.029%;
- maximum PVC-activity PSF CV before SUVR normalization: 8.587%;
- no ROI exceeds 10% CV by either measure.

The PSF-specific cerebellar reference changes by 6.858% from the 4 mm to
8 mm assumptions. Accordingly, normalized SUVR sensitivity and
pre-normalization PVC-activity sensitivity are reported separately.

## Quality control

Direct visual review retained motion/static-PET QC, atlas/reference QC,
raw-versus-PVC ROI comparison and the SUVR/PSF contact sheet. A combined
three-plane PET-T1 coregistration figure and a robust primary-gray PSF figure
were approved for the public portfolio.

## Limitations

This is a single healthy-young-adult demonstration and is not intended for
clinical interpretation. The nominal 5 mm PSF follows the published
post-reconstruction filter and is not a direct measurement of the final
effective scanner resolution.

## Reproducibility

Tool versions are documented in `env/TOOL_VERSIONS.md`. Detailed methods,
results, tables and QC decisions are provided in the repository.
