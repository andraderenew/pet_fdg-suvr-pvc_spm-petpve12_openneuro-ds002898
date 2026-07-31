#!/usr/bin/env bash
set -euo pipefail

SUBJECT="${1:-sub-01}"
DATASET="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/openneuro-ds002898"
PROJECT_ROOT="/media/andraderenew/Elements/neuroimaging/pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
WORK="$PROJECT_ROOT/work/$SUBJECT"

PET_GZ="$DATASET/$SUBJECT/pet/${SUBJECT}_task-rest_trc-18FFDG_rec-acdyn_run-001_pet.nii.gz"
PET_NII="$WORK/${SUBJECT}_source_pet_uncompressed.nii"
PET_JSON="$DATASET/$SUBJECT/pet/${SUBJECT}_task-rest_trc-18FFDG_rec-acdyn_run-001_pet.json"

RAW_MEAN="$WORK/${SUBJECT}_desc-30to90min_raw_mean_native_pet.nii.gz"
SELECTED="$WORK/${SUBJECT}_desc-30to90min_res-2p8mm_pet.nii"
MOCO="$WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_pet.nii.gz"
MOCO_BASE="${MOCO%.nii.gz}"
PAR_CANONICAL="${MOCO_BASE}.par"
MOCO_MEAN="$WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_mean_pet.nii.gz"
MOCO_SUM="$WORK/${SUBJECT}_desc-30to90min_res-2p8mm_moco_sum_pet.nii.gz"
LOG="$HOME/Downloads/ds002898_${SUBJECT}_prepare_static_$(date +%Y%m%d_%H%M%S).log"

export FSLOUTPUTTYPE=NIFTI_GZ
exec > >(tee "$LOG") 2>&1

die() {
    echo "ERROR: $*" >&2
    exit 1
}

for cmd in python3 gzip mcflirt fslval fslmaths; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing command: $cmd"
done

python3 - <<'PY'
import importlib
missing = []
for name in ("nibabel", "numpy", "scipy", "matplotlib"):
    try:
        importlib.import_module(name)
    except Exception:
        missing.append(name)
if missing:
    raise SystemExit(
        "ERROR: missing Python packages: "
        + ", ".join(missing)
        + "\nRun: python -m pip install nibabel numpy scipy matplotlib"
    )
PY

[[ -s "$PET_GZ" ]] || die "missing source PET: $PET_GZ"
[[ -s "$PET_JSON" ]] || die "missing PET JSON: $PET_JSON"
mkdir -p "$WORK"

echo "=== DISK SPACE ==="
df -h "$PROJECT_ROOT"
AVAILABLE_KB="$(df -Pk "$PROJECT_ROOT" | awk 'NR==2 {print $4}')"
REQUIRED_KB=$((55 * 1024 * 1024))
(( AVAILABLE_KB >= REQUIRED_KB )) || die "less than 55 GB free"

echo "=== DECOMPRESSING SOURCE PET ==="
if [[ ! -s "$PET_NII" ]]; then
    gzip -dc "$PET_GZ" > "${PET_NII}.partial"
    mv "${PET_NII}.partial" "$PET_NII"
fi

echo "=== STREAMING 225 FRAMES TO A 2.8 MM GRID ==="
if [[ ! -s "$SELECTED" || ! -s "$RAW_MEAN" ]]; then
python3 - "$PET_NII" "$PET_JSON" "$RAW_MEAN" "$SELECTED" "$WORK/frame_selection.json" <<'PY'
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import nibabel as nib
import numpy as np
from nibabel.processing import resample_from_to, resample_to_output

pet_path = Path(sys.argv[1])
json_path = Path(sys.argv[2])
raw_mean_path = Path(sys.argv[3])
selected_path = Path(sys.argv[4])
summary_path = Path(sys.argv[5])

image = nib.load(str(pet_path), mmap="r")
metadata = json.loads(json_path.read_text(encoding="utf-8"))
starts = np.asarray(metadata["FrameTimesStart"], dtype=float)
durations = np.asarray(metadata["FrameDuration"], dtype=float)

if image.shape != (344, 344, 127, 356):
    raise SystemExit(f"ERROR: unexpected PET shape: {image.shape}")
if len(starts) != 356 or len(durations) != 356:
    raise SystemExit("ERROR: frame metadata count mismatch")
if not np.allclose(durations, 16.0):
    raise SystemExit("ERROR: expected equal 16-second frames")

indices = np.where((starts >= 1800.0) & (starts < 5400.0))[0]
if not np.array_equal(indices, np.arange(113, 338)):
    raise SystemExit(
        f"ERROR: unexpected selected indices: {indices[0]}..{indices[-1]}"
    )

first_native = np.asarray(image.dataobj[..., int(indices[0])], dtype=np.float32)
first_img = nib.Nifti1Image(first_native, image.affine, image.header)
first_resampled = resample_to_output(
    first_img,
    voxel_sizes=(2.8, 2.8, 2.8),
    order=1,
)
target_shape = first_resampled.shape
target_affine = first_resampled.affine
target = (target_shape, target_affine)

n_frames = len(indices)
dtype = np.dtype("<f4")
vox_offset = 352
n_bytes = int(np.prod(target_shape) * n_frames * dtype.itemsize)

header = first_resampled.header.copy()
header.set_data_shape(target_shape + (n_frames,))
header.set_data_dtype(dtype)
header.set_zooms((2.8, 2.8, 2.8, 16.0))
header["vox_offset"] = float(vox_offset)
header["scl_slope"] = 1.0
header["scl_inter"] = 0.0
header.set_qform(target_affine, code=1)
header.set_sform(target_affine, code=1)

partial = selected_path.with_suffix(selected_path.suffix + ".partial")
partial.unlink(missing_ok=True)

with partial.open("wb") as stream:
    header.write_to(stream)
    stream.write(b"\x00\x00\x00\x00")
    stream.truncate(vox_offset + n_bytes)

disk_array = np.memmap(
    partial,
    dtype=dtype,
    mode="r+",
    offset=vox_offset,
    shape=target_shape + (n_frames,),
    order="F",
)

native_sum = np.zeros(image.shape[:3], dtype=np.float64)

for output_index, source_index in enumerate(indices):
    native = np.asarray(
        image.dataobj[..., int(source_index)],
        dtype=np.float32,
    )
    native_sum += native

    if output_index == 0:
        resampled = np.asarray(
            first_resampled.get_fdata(dtype=np.float32),
            dtype=np.float32,
        )
    else:
        frame_img = nib.Nifti1Image(native, image.affine, image.header)
        resampled_img = resample_from_to(frame_img, target, order=1)
        resampled = np.asarray(
            resampled_img.get_fdata(dtype=np.float32),
            dtype=np.float32,
        )

    disk_array[..., output_index] = resampled

    if output_index == 0 or (output_index + 1) % 10 == 0 or output_index == 224:
        disk_array.flush()
        print(f"Processed {output_index + 1}/225 frames", flush=True)

disk_array.flush()
del disk_array
os.replace(partial, selected_path)

native_mean = (native_sum / 225.0).astype(np.float32)
native_header = image.header.copy()
native_header.set_data_shape(image.shape[:3])
native_header.set_data_dtype(np.float32)
nib.save(
    nib.Nifti1Image(native_mean, image.affine, native_header),
    str(raw_mean_path),
)

check = nib.load(str(selected_path), mmap="r")
if check.shape != (172, 172, 93, 225):
    raise SystemExit(f"ERROR: invalid streamed PET shape: {check.shape}")

summary = {
    "subject": "sub-01",
    "selection_rule": "FrameTimesStart >= 1800 and < 5400 seconds",
    "zero_based_indices": [113, 337],
    "one_based_frames": [114, 338],
    "selected_frame_count": 225,
    "first_start_seconds": float(starts[113]),
    "last_start_seconds": float(starts[337]),
    "last_end_seconds": float(starts[337] + durations[337]),
    "resampling": {
        "voxel_size_mm": [2.8, 2.8, 2.8],
        "interpolation": "trilinear",
        "shape": [172, 172, 93],
    },
}
summary_path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
PY
fi

DIM4="$(fslval "$SELECTED" dim4 | tr -d '[:space:]')"
[[ "$DIM4" == "225" ]] || die "selected PET dim4=$DIM4"

echo "=== MCFLIRT MOTION CORRECTION ==="
if [[ ! -s "$MOCO" ]]; then
    mcflirt \
        -in "$SELECTED" \
        -out "$MOCO" \
        -cost normcorr \
        -meanvol \
        -plots \
        -mats \
        -rmsrel \
        -rmsabs \
        -report
fi

MOCO_DIM4="$(fslval "$MOCO" dim4 | tr -d '[:space:]')"
[[ "$MOCO_DIM4" == "225" ]] || die "MCFLIRT PET dim4=$MOCO_DIM4"

echo "=== LOCATING MCFLIRT PARAMETERS ==="
if [[ ! -s "$PAR_CANONICAL" ]]; then
PAR_REAL="$(
python3 - "$WORK" "$MOCO" <<'PY'
from pathlib import Path
import sys
import numpy as np

work = Path(sys.argv[1])
moco = Path(sys.argv[2])

candidates = [
    Path(str(moco) + ".par"),
    moco.with_suffix(".par"),
    Path(str(moco).removesuffix(".gz") + ".par"),
    *sorted(work.glob("*moco_pet*.par")),
    *sorted(work.glob("*.par")),
]

valid = []
seen = set()
for path in candidates:
    path = path.resolve()
    if path in seen or not path.is_file() or path.stat().st_size == 0:
        continue
    seen.add(path)
    try:
        values = np.loadtxt(path)
    except Exception:
        continue
    if values.ndim == 1:
        values = values.reshape(1, -1)
    if values.shape == (225, 6):
        valid.append(path)

if valid:
    valid.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    print(valid[0])
PY
)"
    [[ -n "$PAR_REAL" ]] || die "no valid 225 x 6 MCFLIRT .par file found"
    cp -f "$PAR_REAL" "$PAR_CANONICAL"
fi

echo "=== STATIC MEAN AND SUM ==="
if [[ ! -s "$MOCO_MEAN" ]]; then
    fslmaths "$MOCO" -Tmean "$MOCO_MEAN"
fi
fslmaths "$MOCO_MEAN" -mul 225 "$MOCO_SUM"

echo "=== MOTION SUMMARY AND QC ==="
python3 - "$PAR_CANONICAL" "$RAW_MEAN" "$MOCO_MEAN" "$WORK" <<'PY'
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np

par_path = Path(sys.argv[1])
raw_path = Path(sys.argv[2])
moco_path = Path(sys.argv[3])
work = Path(sys.argv[4])

params = np.loadtxt(par_path)
if params.ndim == 1:
    params = params.reshape(1, -1)
if params.shape != (225, 6):
    raise SystemExit(f"ERROR: expected 225 x 6 parameters, got {params.shape}")

rot = params[:, :3]
trans = params[:, 3:]
relative = np.diff(params, axis=0, prepend=params[[0], :])

summary = {
    "parameter_file": str(par_path),
    "frame_count": 225,
    "maximum_absolute_rotation_radians": [
        float(value) for value in np.max(np.abs(rot), axis=0)
    ],
    "maximum_absolute_translation_mm": [
        float(value) for value in np.max(np.abs(trans), axis=0)
    ],
    "maximum_frame_to_frame_rotation_radians": [
        float(value) for value in np.max(np.abs(relative[:, :3]), axis=0)
    ],
    "maximum_frame_to_frame_translation_mm": [
        float(value) for value in np.max(np.abs(relative[:, 3:]), axis=0)
    ],
}
(work / "motion_summary.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)

with (work / "motion_parameters.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.writer(stream)
    writer.writerow([
        "frame", "rot_x_rad", "rot_y_rad", "rot_z_rad",
        "trans_x_mm", "trans_y_mm", "trans_z_mm",
    ])
    for index, row in enumerate(params, start=1):
        writer.writerow([index, *[float(value) for value in row]])

x = np.arange(1, 226)
for data, ylabel, title, filename in (
    (trans, "Translation (mm)", "MCFLIRT translations", "qc_motion_translations.png"),
    (rot, "Rotation (radians)", "MCFLIRT rotations", "qc_motion_rotations.png"),
):
    fig = plt.figure(figsize=(10, 5))
    for column, label in enumerate(("x", "y", "z")):
        plt.plot(x, data[:, column], label=label)
    plt.xlabel("Selected PET frame")
    plt.ylabel(ylabel)
    plt.title(title)
    plt.legend()
    plt.tight_layout()
    fig.savefig(work / filename, dpi=180)
    plt.close(fig)

def save_planes(path: Path, prefix: str, title: str) -> None:
    image = nib.load(str(path))
    data = np.asarray(image.get_fdata(dtype=np.float32))
    mids = [size // 2 for size in data.shape]
    planes = [
        np.rot90(data[mids[0], :, :]),
        np.rot90(data[:, mids[1], :]),
        np.rot90(data[:, :, mids[2]]),
    ]
    finite = data[np.isfinite(data)]
    low, high = np.percentile(finite, [1, 99])
    for number, plane in enumerate(planes, start=1):
        fig = plt.figure(figsize=(5, 5))
        plt.imshow(plane, origin="lower", vmin=low, vmax=high)
        plt.axis("off")
        plt.title(f"{title} - plane {number}")
        plt.tight_layout()
        fig.savefig(work / f"{prefix}_plane-{number}.png", dpi=180, bbox_inches="tight")
        plt.close(fig)

save_planes(raw_path, "qc_raw_mean_native", "Native static FDG")
save_planes(moco_path, "qc_moco_mean_2p8mm", "2.8 mm static FDG after MCFLIRT")
print(json.dumps(summary, indent=2))
PY

echo "=== COMPLETE ==="
echo "Static PET:"
echo "  $MOCO_MEAN"
echo "Log:"
echo "  $LOG"
