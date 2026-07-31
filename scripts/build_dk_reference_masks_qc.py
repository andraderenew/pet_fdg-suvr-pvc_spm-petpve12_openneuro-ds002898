from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np

subject = "sub-01"
project_root = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
)
work = project_root / "work" / subject
spm_work = work / "spm"
atlas_work = work / "atlas"

pet_path = (
    spm_work
    / f"{subject}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
)
t1_path = spm_work / f"rm{subject}_T1w.nii"
gm_path = spm_work / f"rc1{subject}_T1w.nii"
atlas_source = atlas_work / "rwDesikan-Killiany_MNI_SPM12.nii"

atlas_output = (
    atlas_work
    / f"{subject}_space-pet_desc-desikan-killiany_atlas.nii.gz"
)
cereb_output = (
    atlas_work
    / f"{subject}_space-pet_desc-bilateral-cerebellar-cortex_mask.nii.gz"
)
gm_weight_output = (
    atlas_work
    / f"{subject}_space-pet_desc-bilateral-cerebellar-cortex_gmweight.nii.gz"
)
gm30_output = (
    atlas_work
    / f"{subject}_space-pet_desc-bilateral-cerebellar-cortex-gm30_mask.nii.gz"
)
gm50_output = (
    atlas_work
    / f"{subject}_space-pet_desc-bilateral-cerebellar-cortex-gm50_mask.nii.gz"
)

for path in (pet_path, t1_path, gm_path, atlas_source):
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: missing file: {path}")

pet_img = nib.load(str(pet_path))
t1_img = nib.load(str(t1_path))
gm_img = nib.load(str(gm_path))
atlas_img = nib.load(str(atlas_source))

for image in (t1_img, gm_img, atlas_img):
    if image.shape != pet_img.shape:
        raise SystemExit(
            f"ERROR: grid shape mismatch: {image.shape} vs {pet_img.shape}"
        )
    if not np.allclose(image.affine, pet_img.affine, atol=1e-4):
        raise SystemExit("ERROR: affine mismatch in atlas/reference stage")

pet = pet_img.get_fdata(dtype=np.float32)
t1 = t1_img.get_fdata(dtype=np.float32)
gm = np.clip(gm_img.get_fdata(dtype=np.float32), 0.0, 1.0)
atlas_float = atlas_img.get_fdata(dtype=np.float32)
atlas = np.rint(atlas_float).astype(np.int16)

present_labels = set(int(value) for value in np.unique(atlas))
for required in (8, 47):
    if required not in present_labels:
        raise SystemExit(
            f"ERROR: cerebellar cortex label {required} is absent"
        )

cereb = np.isin(atlas, [8, 47])
gm_weight = np.where(cereb, gm, 0.0).astype(np.float32)
gm30 = cereb & (gm >= 0.30)
gm50 = cereb & (gm >= 0.50)

voxel_volume = float(abs(np.linalg.det(pet_img.affine[:3, :3])))

summary = {
    "subject": subject,
    "atlas": "PETPVE12 Desikan-Killiany MNI SPM12",
    "reference_labels": {
        "8": "lh-Cerebellum-Cortex",
        "47": "rh-Cerebellum-Cortex",
    },
    "shape": list(pet_img.shape),
    "voxel_sizes_mm": [
        float(value) for value in pet_img.header.get_zooms()[:3]
    ],
    "voxel_volume_mm3": voxel_volume,
    "cerebellar_atlas_voxels": int(np.count_nonzero(cereb)),
    "cerebellar_atlas_volume_mm3": (
        float(np.count_nonzero(cereb)) * voxel_volume
    ),
    "cerebellar_gm30_voxels": int(np.count_nonzero(gm30)),
    "cerebellar_gm50_voxels": int(np.count_nonzero(gm50)),
    "gm_weight_sum": float(gm_weight.sum()),
    "present_label_count": len(present_labels - {0}),
}

if summary["cerebellar_atlas_voxels"] < 100:
    raise SystemExit("ERROR: cerebellar atlas mask is unexpectedly small")
if summary["cerebellar_gm50_voxels"] < 20:
    raise SystemExit("ERROR: cerebellar GM50 reference mask is too small")

atlas_header = atlas_img.header.copy()
atlas_header.set_data_dtype(np.int16)
nib.save(
    nib.Nifti1Image(atlas, pet_img.affine, atlas_header),
    str(atlas_output),
)

mask_header = pet_img.header.copy()
mask_header.set_data_dtype(np.uint8)

for output, data in (
    (cereb_output, cereb.astype(np.uint8)),
    (gm30_output, gm30.astype(np.uint8)),
    (gm50_output, gm50.astype(np.uint8)),
):
    nib.save(
        nib.Nifti1Image(data, pet_img.affine, mask_header),
        str(output),
    )

weight_header = pet_img.header.copy()
weight_header.set_data_dtype(np.float32)
nib.save(
    nib.Nifti1Image(gm_weight, pet_img.affine, weight_header),
    str(gm_weight_output),
)

(atlas_work / "dk_reference_summary.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)

cereb_coords = np.argwhere(gm30)
center = np.round(cereb_coords.mean(axis=0)).astype(int)

brain_coords = np.argwhere(np.isfinite(pet) & (pet > np.percentile(pet[pet > 0], 60)))
brain_center = np.round(brain_coords.mean(axis=0)).astype(int)

t1_finite = t1[np.isfinite(t1)]
pet_positive = pet[np.isfinite(pet) & (pet > 0)]
t1_low, t1_high = np.percentile(t1_finite, [1, 99])
pet_low, pet_high = np.percentile(pet_positive, [5, 99])

fig, axes = plt.subplots(2, 3, figsize=(18, 11))

definitions = [
    ("Sagittal cerebellum", 0, center[0]),
    ("Coronal cerebellum", 1, center[1]),
    ("Axial cerebellum", 2, center[2]),
    ("Sagittal brain", 0, brain_center[0]),
    ("Coronal brain", 1, brain_center[1]),
    ("Axial brain", 2, brain_center[2]),
]

def plane(data: np.ndarray, axis: int, index: int) -> np.ndarray:
    if axis == 0:
        return np.rot90(data[index, :, :])
    if axis == 1:
        return np.rot90(data[:, index, :])
    return np.rot90(data[:, :, index])

for ax, (title, axis, index) in zip(axes.flat, definitions):
    t1_plane = plane(t1, axis, index)
    pet_plane = plane(pet, axis, index)
    cereb_plane = plane(cereb.astype(float), axis, index)
    atlas_plane = plane((atlas > 0).astype(float), axis, index)

    ax.imshow(t1_plane, origin="lower", vmin=t1_low, vmax=t1_high)
    ax.imshow(
        np.ma.masked_where(pet_plane <= pet_low, pet_plane),
        origin="lower",
        alpha=0.35,
        vmin=pet_low,
        vmax=pet_high,
    )

    if np.any(atlas_plane > 0):
        ax.contour(atlas_plane, levels=[0.5], linewidths=0.35)
    if np.any(cereb_plane > 0):
        ax.contour(cereb_plane, levels=[0.5], linewidths=1.2)

    ax.set_title(title)
    ax.axis("off")

fig.suptitle(
    "OpenNeuro ds002898 sub-01 - DK atlas and bilateral cerebellar cortex QC",
    fontsize=16,
)
plt.tight_layout(rect=(0, 0, 1, 0.95))

qc_path = atlas_work / "qc_dk_atlas_reference_contact_sheet.png"
fig.savefig(qc_path, dpi=180, bbox_inches="tight")
plt.close(fig)

print(json.dumps(summary, indent=2))
print(f"QC image: {qc_path}")
