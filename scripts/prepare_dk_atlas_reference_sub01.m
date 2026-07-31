function prepare_dk_atlas_reference_sub01
clear;
clc;

subject = 'sub-01';
spm12_dir = '/home/andraderenew/Downloads/spm12';
petpve12_dir = fullfile(spm12_dir, 'toolbox', 'petpve12');

project_root = ['/media/andraderenew/Elements/neuroimaging/' ...
    'pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898'];

spm_work = fullfile(project_root, 'work', subject, 'spm');
atlas_work = fullfile(project_root, 'work', subject, 'atlas');

t1_file = fullfile(atlas_work, [subject '_T1w_atlasprep.nii']);
pet_file = fullfile(spm_work, ...
    [subject '_desc-30to90min_res-2p8mm_moco_mean_pet.nii']);
dk_atlas = fullfile(petpve12_dir, 'Atlases', ...
    'Desikan-Killiany_MNI_SPM12.nii');

m_t1 = fullfile(atlas_work, ['m' subject '_T1w_atlasprep.nii']);
y_t1 = fullfile(atlas_work, ['y_' subject '_T1w_atlasprep.nii']);
iy_t1 = fullfile(atlas_work, ['iy_' subject '_T1w_atlasprep.nii']);
warped_atlas = fullfile(atlas_work, ...
    'wDesikan-Killiany_MNI_SPM12.nii');
pet_atlas = fullfile(atlas_work, ...
    'rwDesikan-Killiany_MNI_SPM12.nii');

addpath(spm12_dir);
spm('defaults', 'PET');
spm_jobman('initcfg');

if ~isfile(iy_t1) || ~isfile(m_t1)
    fprintf('=== SPM SEGMENTATION FOR BOTH DEFORMATION FIELDS ===\n');

    matlabbatch = {};
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {t1_file};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];

    ngaus = [1 1 2 3 4 2];

    for tissue_index = 1:6
        matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).tpm = ...
            {sprintf('%s/tpm/TPM.nii,%d', ...
            spm12_dir, tissue_index)};
        matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).ngaus = ...
            ngaus(tissue_index);
        matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).native = ...
            [0 0];
        matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).warped = ...
            [0 0];
    end

    matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg = ...
        [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;

    % SPM order is [inverse forward].
    % Save both iy_* and y_* deformation fields.
    matlabbatch{1}.spm.spatial.preproc.warp.write = [1 1];

    spm_jobman('run', matlabbatch);
end

if ~isfile(iy_t1)
    error('Missing inverse deformation field after segmentation: %s', iy_t1);
end
if ~isfile(y_t1)
    error('Missing forward deformation field after segmentation: %s', y_t1);
end
if ~isfile(m_t1)
    error('Missing bias-corrected T1: %s', m_t1);
end

fprintf('Forward deformation: %s\n', y_t1);
fprintf('Inverse deformation: %s\n', iy_t1);

if ~isfile(warped_atlas)
    fprintf('=== WARPING DK ATLAS FROM MNI TO SUBJECT T1 ===\n');

    matlabbatch = {};
    matlabbatch{1}.spm.util.defs.comp{1}.def = {iy_t1};
    matlabbatch{1}.spm.util.defs.out{1}.pull.fnames = {dk_atlas};
    matlabbatch{1}.spm.util.defs.out{1}.pull.savedir.saveusr = ...
        {atlas_work};
    matlabbatch{1}.spm.util.defs.out{1}.pull.interp = 0;
    matlabbatch{1}.spm.util.defs.out{1}.pull.mask = 0;
    matlabbatch{1}.spm.util.defs.out{1}.pull.fwhm = [0 0 0];

    spm_jobman('run', matlabbatch);
end

if ~isfile(warped_atlas)
    error('Missing warped atlas: %s', warped_atlas);
end

if ~isfile(pet_atlas)
    fprintf('=== COREGISTERING WARPED ATLAS TO PET ===\n');

    matlabbatch = {};
    matlabbatch{1}.spm.spatial.coreg.estimate.ref = {pet_file};
    matlabbatch{1}.spm.spatial.coreg.estimate.source = {m_t1};
    matlabbatch{1}.spm.spatial.coreg.estimate.other = {warped_atlas};
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.tol = ...
        [0.0200 0.0200 0.0200 0.0010 0.0010 0.0010 ...
         0.0100 0.0100 0.0100 0.0010 0.0010 0.0010];
    matlabbatch{1}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];

    spm_jobman('run', matlabbatch);

    matlabbatch = {};
    matlabbatch{1}.spm.spatial.coreg.write.ref = {pet_file};
    matlabbatch{1}.spm.spatial.coreg.write.source = {warped_atlas};
    matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 0;
    matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.write.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';

    spm_jobman('run', matlabbatch);
end

if ~isfile(pet_atlas)
    error('Missing PET-space atlas: %s', pet_atlas);
end

fprintf('=== ATLAS PREPARATION COMPLETE ===\n');
fprintf('PET-space atlas: %s\n', pet_atlas);
end
