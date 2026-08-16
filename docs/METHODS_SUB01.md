# Methods

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

For raw PET, the bilateral cerebellar reference was calculated as a
GM-probability-weighted mean within Desikan-Killiany labels 8 and 47. For each
PVC PSF output, the reference was calculated as the mean of positive PVC
values within the same cerebellar labels and GM probability >= 0.5. Each PVC
image was divided by its own PSF-specific reference value.

PSF sensitivity was quantified in two complementary ways: coefficient of
variation across the 4/5/6/8 mm cerebellar-normalized PVC SUVR values, and
coefficient of variation across the corresponding regional PVC activities
before SUVR normalization. The former therefore measures sensitivity of the
complete PVC-plus-normalization workflow rather than isolated regional PVC
sensitivity.

The 20-voxel GM-support threshold was introduced post hoc during QA and was
used only to define a robustness subset. Headline robustness statistics were
therefore restricted to predefined cortical and subcortical primary
gray-matter ROIs with at least 20 voxels satisfying GM probability >= 0.5.
All 84 predefined primary ROIs remain in the public tables; three ROIs below
this support threshold are explicitly flagged rather than silently removed.
The full atlas output is retained as a transparent supplementary table.
