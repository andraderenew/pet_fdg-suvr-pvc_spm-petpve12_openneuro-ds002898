function spm_segment_and_coregister_sub01
clear;
clc;

spm12_dir = '/home/andraderenew/Downloads/spm12';
work_dir = '/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/work/sub-01/spm';
t1_file = fullfile(work_dir, 'sub-01_T1w.nii');
pet_file = fullfile(work_dir, 'sub-01_desc-30to90min_res-2p8mm_moco_mean_pet.nii');

addpath(spm12_dir);
spm('defaults', 'PET');
spm_jobman('initcfg');

[~, t1_name, t1_ext] = fileparts(t1_file);
m_t1 = fullfile(work_dir, ['m' t1_name t1_ext]);
c1_t1 = fullfile(work_dir, ['c1' t1_name t1_ext]);
c2_t1 = fullfile(work_dir, ['c2' t1_name t1_ext]);
c3_t1 = fullfile(work_dir, ['c3' t1_name t1_ext]);

fprintf('=== SPM SEGMENTATION ===\n');

matlabbatch = {};
matlabbatch{1}.spm.spatial.preproc.channel.vols = {t1_file};
matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1];

ngaus = [1 1 2 3 4 2];
native_write = [
    1 0
    1 0
    1 0
    0 0
    0 0
    0 0
];

for tissue_index = 1:6
    matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).tpm = {
        sprintf('%s/tpm/TPM.nii,%d', spm12_dir, tissue_index)
    };
    matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).ngaus = ngaus(tissue_index);
    matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).native = native_write(tissue_index,:);
    matlabbatch{1}.spm.spatial.preproc.tissue(tissue_index).warped = [0 0];
end

matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0];

spm_jobman('run', matlabbatch);

required_seg = {m_t1, c1_t1, c2_t1, c3_t1};
for index = 1:numel(required_seg)
    if ~isfile(required_seg{index})
        error('Missing segmentation output: %s', required_seg{index});
    end
end

fprintf('=== SPM COREGISTRATION: T1/TISSUES TO PET SPACE ===\n');

matlabbatch = {};
matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {pet_file};
matlabbatch{1}.spm.spatial.coreg.estwrite.source = {m_t1};
matlabbatch{1}.spm.spatial.coreg.estwrite.other = {
    c1_t1
    c2_t1
    c3_t1
};
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [
    0.0200 0.0200 0.0200 0.0010 0.0010 0.0010 ...
    0.0100 0.0100 0.0100 0.0010 0.0010 0.0010
];
matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 1;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';

spm_jobman('run', matlabbatch);

r_m_t1 = fullfile(work_dir, ['rm' t1_name t1_ext]);
rc1_t1 = fullfile(work_dir, ['rc1' t1_name t1_ext]);
rc2_t1 = fullfile(work_dir, ['rc2' t1_name t1_ext]);
rc3_t1 = fullfile(work_dir, ['rc3' t1_name t1_ext]);

required_coreg = {r_m_t1, rc1_t1, rc2_t1, rc3_t1};
for index = 1:numel(required_coreg)
    if ~isfile(required_coreg{index})
        error('Missing coregistration output: %s', required_coreg{index});
    end
end

fprintf('=== SPM STAGE COMPLETE ===\n');
fprintf('PET reference: %s\n', pet_file);
fprintf('Coregistered T1: %s\n', r_m_t1);
fprintf('Coregistered GM: %s\n', rc1_t1);
fprintf('Coregistered WM: %s\n', rc2_t1);
fprintf('Coregistered CSF: %s\n', rc3_t1);
end
