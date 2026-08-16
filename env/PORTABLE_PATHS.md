# Portable path configuration

The workflow no longer embeds workstation-specific filesystem paths.

## Processing root

Set `PET_PROJECT_ROOT` to the directory containing the local `work/` directory.
If it is not set, scripts default to the repository root.

```bash
export PET_PROJECT_ROOT=/path/to/pet-processing-root
```

The default dataset location is:

```text
$PET_PROJECT_ROOT/openneuro-ds002898
```

## SPM12 and PETPVE12

Stages using MATLAB/SPM require:

```bash
export SPM12_DIR=/path/to/spm12
```

PETPVE12 is expected under:

```text
$SPM12_DIR/toolbox/petpve12
```

`SPM12_DIR` is also required by the SUVR stage because the
Desikan-Killiany label description is read from the PETPVE12 installation.

## MATLAB executable

MATLAB-enabled Bash stages resolve `matlab` from `PATH` by default.
Override the executable when needed:

```bash
export MATLAB_BIN=/path/to/matlab
```

Raw imaging and large intermediate derivatives remain excluded from Git.
Runtime logs are written under `$PET_PROJECT_ROOT/work/sub-01/logs/`, which remains outside the public Git payload.
