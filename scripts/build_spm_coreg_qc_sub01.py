from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np

work = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/"
    "work/sub-01/spm"
)
subject = "sub-01"

pet_path = work / f"{subject}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
t1_path = work / f"rm{subject}_T1w.nii"
gm_path = work / f"rc1{subject}_T1w.nii"
wm_path = work / f"rc2{subject}_T1w.nii"
csf_path = work / f"rc3{subject}_T1w.nii"

for path in (pet_path, t1_path, gm_path, wm_path, csf_path):
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: missing file: {path}")

pet_img = nib.load(str(pet_path))
t1_img = nib.load(str(t1_path))
gm_img = nib.load(str(gm_path))
wm_img = nib.load(str(wm_path))
csf_img = nib.load(str(csf_path))

for image in (t1_img, gm_img, wm_img, csf_img):
    if image.shape != pet_img.shape:
        raise SystemExit(
            f"ERROR: grid mismatch: PET {pet_img.shape}, other {image.shape}"
        )
    if not np.allclose(image.affine, pet_img.affine, atol=1e-4):
        raise SystemExit("ERROR: affine mismatch after SPM coregistration")

pet = pet_img.get_fdata(dtype=np.float32)
t1 = t1_img.get_fdata(dtype=np.float32)
gm = gm_img.get_fdata(dtype=np.float32)
wm = wm_img.get_fdata(dtype=np.float32)
csf = csf_img.get_fdata(dtype=np.float32)

positive_pet = pet[np.isfinite(pet) & (pet > 0)]
if positive_pet.size == 0:
    raise SystemExit("ERROR: PET contains no positive finite values")

threshold = np.percentile(positive_pet, 60)
coords = np.argwhere(np.isfinite(pet) & (pet >= threshold))
center = np.round(coords.mean(axis=0)).astype(int)

planes = {
    "sagittal": (
        np.rot90(t1[center[0], :, :]),
        np.rot90(pet[center[0], :, :]),
        np.rot90((gm + wm + csf)[center[0], :, :]),
    ),
    "coronal": (
        np.rot90(t1[:, center[1], :]),
        np.rot90(pet[:, center[1], :]),
        np.rot90((gm + wm + csf)[:, center[1], :]),
    ),
    "axial": (
        np.rot90(t1[:, :, center[2]]),
        np.rot90(pet[:, :, center[2]]),
        np.rot90((gm + wm + csf)[:, :, center[2]]),
    ),
}

t1_finite = t1[np.isfinite(t1)]
pet_finite = pet[np.isfinite(pet)]
t1_low, t1_high = np.percentile(t1_finite, [1, 99])
pet_low, pet_high = np.percentile(pet_finite, [20, 99])

outputs = []
for name, (t1_plane, pet_plane, tissue_plane) in planes.items():
    fig = plt.figure(figsize=(8, 8))
    plt.imshow(t1_plane, origin="lower", vmin=t1_low, vmax=t1_high)
    plt.imshow(
        np.ma.masked_where(pet_plane <= pet_low, pet_plane),
        origin="lower",
        alpha=0.45,
        vmin=pet_low,
        vmax=pet_high,
    )
    if np.nanmax(tissue_plane) > 0.5:
        plt.contour(tissue_plane, levels=[0.5], linewidths=0.7)
    plt.title(f"SPM coregistration QC - {name}")
    plt.axis("off")
    plt.tight_layout()

    output = work / f"qc_spm_coreg_{name}.png"
    fig.savefig(output, dpi=180, bbox_inches="tight")
    plt.close(fig)
    outputs.append(str(output))

summary = {
    "subject": subject,
    "pet_reference": str(pet_path),
    "coregistered_t1": str(t1_path),
    "coregistered_gm": str(gm_path),
    "coregistered_wm": str(wm_path),
    "coregistered_csf": str(csf_path),
    "shape": list(pet_img.shape),
    "voxel_sizes_mm": [float(value) for value in pet_img.header.get_zooms()[:3]],
    "qc_center_voxel": [int(value) for value in center],
    "qc_images": outputs,
}

(work / "spm_segment_coreg_summary.json").write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)

print(json.dumps(summary, indent=2))
