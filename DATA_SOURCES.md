# Data source

## Replacement dataset

This project now uses the openly downloadable OpenNeuro dataset:

- Dataset: Monash resting-state simultaneous FDG-fPET/MRI
- OpenNeuro accession: `ds002898`
- Dataset DOI: `10.18112/openneuro.ds002898.v1.0.0`
- Source paper: Jamadar SD, Ward PGD, Close TG, et al. *Scientific Data*. 2020;7:363.
- Participants: 27 healthy young adults
- Relevant modalities: T1-weighted MRI and dynamic FDG PET
- Access: public OpenNeuro download; no institutional email required

## Planned subset

One subject will be selected after listing the public dataset contents. The subject must contain:

- one T1w NIfTI image;
- one dynamic FDG PET NIfTI image;
- the corresponding PET JSON sidecar;
- timing metadata sufficient to select the 30–90 minute interval.

The selected subject identifier and exact source file names will be recorded before analysis.

## Static PET definition

The source study describes 356 PET frames at 16-second intervals. For its main processing, 225 frames beginning at 30 minutes were retained and summed to create a static PET image. This project will reproduce that definition using the PET sidecar timing arrays rather than relying on hard-coded frame numbers.

## Resolution handling

The source PET reconstruction included point-spread-function correction and a 5 mm FWHM Gaussian post-filter. Because the post-filter is not automatically identical to the final effective image resolution required by PETPVE12, the workflow will document a resolution sensitivity analysis rather than claiming an unverified exact PSF.

## Storage and redistribution

Source OpenNeuro data and heavy derivatives remain on the local external drive and are excluded from Git. The repository will contain scripts, methods, logs, compact numerical summaries, and non-identifying QC figures.

## Historical note
