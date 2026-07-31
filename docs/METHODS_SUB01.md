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

Headline PSF-sensitivity statistics were restricted to primary cortical and
subcortical gray-matter ROIs. The full atlas output was retained as a
transparent supplementary table.
