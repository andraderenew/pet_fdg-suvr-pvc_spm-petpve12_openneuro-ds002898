function run_petpve12_psf_sensitivity_sub01
clear;
clc;

subject = 'sub-01';
spm12_dir = '/home/andraderenew/Downloads/spm12';
petpve12_dir = fullfile(spm12_dir, 'toolbox', 'petpve12');
pvc_root = ['/media/andraderenew/Elements/neuroimaging/' ...
    'pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/' ...
    'work/sub-01/petpve12'];

addpath(spm12_dir);
addpath(genpath(petpve12_dir));

spm('defaults', 'PET');
spm_jobman('initcfg');
geg_petpve12_defaults;

psf_values = [4 5 6 8];

for index = 1:numel(psf_values)
    psf = psf_values(index);
    run_dir = fullfile(pvc_root, sprintf('psf-%dmm', psf));

    pet_file = fullfile(run_dir, [subject '_pet.nii']);
    gm_file = fullfile(run_dir, [subject '_gm.nii']);
    wm_file = fullfile(run_dir, [subject '_wm.nii']);
    csf_file = fullfile(run_dir, [subject '_csf.nii']);

    required_files = {pet_file, gm_file, wm_file, csf_file};
    for file_index = 1:numel(required_files)
        if ~isfile(required_files{file_index})
            error('Missing PETPVE12 input: %s', required_files{file_index});
        end
    end

    expected_output = fullfile(run_dir, ['pvc' subject '_pet.nii']);

    if isfile(expected_output)
        fprintf('Reusing existing PETPVE12 output for PSF %d mm:\n', psf);
        fprintf('  %s\n', expected_output);
        continue;
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('PETPVE12 MG: isotropic PSF %d mm\n', psf);
    fprintf('============================================================\n');

    job = struct;
    job.PETdata = {pet_file};
    job.SegImgs.Tsegs.tiss1 = {gm_file};
    job.SegImgs.Tsegs.tiss2 = {wm_file};
    job.PVEopts.fwhm_PSF = [psf psf psf];
    job.PVEopts.gmthresh = 0.5;
    job.PVEopts.CSFsignal.CSFcalc.tiss3 = {csf_file};
    job.PVEopts.TissConv = 0;
    job.PVE_Const_opts.type3.wmcsfthresh = 0.9;

    geg_PVEcorrection(job);

    if ~isfile(expected_output)
        error('PETPVE12 did not create expected output: %s', expected_output);
    end
end

fprintf('\nPETPVE12 sensitivity stage complete.\n');
end
