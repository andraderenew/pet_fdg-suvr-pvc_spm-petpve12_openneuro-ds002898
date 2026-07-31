from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
import pandas as pd

subject = "sub-01"
project_root = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
)
work = project_root / "work" / subject
spm_work = work / "spm"
atlas_work = work / "atlas"
pvc_root = work / "petpve12"
results = work / "results"
results.mkdir(parents=True, exist_ok=True)

pet_path = (
    spm_work
    / f"{subject}_desc-30to90min_res-2p8mm_moco_mean_pet.nii"
)
gm_path = spm_work / f"rc1{subject}_T1w.nii"
atlas_path = (
    atlas_work
    / f"{subject}_space-pet_desc-desikan-killiany_atlas.nii.gz"
)
descriptor_path = (
    Path("/home/andraderenew/Downloads/spm12/toolbox/petpve12")
    / "Atlases"
    / "Desikan-Killiany_MNI_SPM12.txt"
)

for path in (pet_path, gm_path, atlas_path, descriptor_path):
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: missing input: {path}")

pet_img = nib.load(str(pet_path))
gm_img = nib.load(str(gm_path))
atlas_img = nib.load(str(atlas_path))

for image in (gm_img, atlas_img):
    if image.shape != pet_img.shape:
        raise SystemExit("ERROR: SUVR input shape mismatch")
    if not np.allclose(image.affine, pet_img.affine, atol=1e-4):
        raise SystemExit("ERROR: SUVR input affine mismatch")

pet = pet_img.get_fdata(dtype=np.float32)
gm = np.clip(gm_img.get_fdata(dtype=np.float32), 0.0, 1.0)
atlas = np.rint(atlas_img.get_fdata(dtype=np.float32)).astype(np.int32)

labels: dict[int, str] = {}
with descriptor_path.open(encoding="utf-8") as stream:
    for line in stream:
        line = line.strip()
        if not line:
            continue
        name, value = line.rsplit("\t", 1)
        labels[int(value)] = name

reference_atlas = np.isin(atlas, [8, 47])
reference_weights = np.where(reference_atlas, gm, 0.0)

raw_reference_valid = (
    np.isfinite(pet)
    & (pet > 0)
    & (reference_weights > 0)
)

raw_weight_sum = float(reference_weights[raw_reference_valid].sum())
if raw_weight_sum <= 0:
    raise SystemExit("ERROR: invalid raw cerebellar GM reference weights")

raw_reference = float(
    np.sum(
        pet[raw_reference_valid]
        * reference_weights[raw_reference_valid]
    )
    / raw_weight_sum
)

if not np.isfinite(raw_reference) or raw_reference <= 0:
    raise SystemExit("ERROR: invalid raw PET reference value")

raw_suvr = (pet / raw_reference).astype(np.float32)
raw_suvr_path = (
    results
    / f"{subject}_desc-raw_cerebellar-cortex_suvr.nii.gz"
)
nib.save(
    nib.Nifti1Image(raw_suvr, pet_img.affine, pet_img.header),
    str(raw_suvr_path),
)

pvc_data: dict[int, np.ndarray] = {}
pvc_suvr: dict[int, np.ndarray] = {}
pvc_reference: dict[int, float] = {}
pvc_paths: dict[int, Path] = {}
suvr_paths: dict[int, Path] = {}

for psf in (4, 5, 6, 8):
    path = (
        pvc_root
        / f"psf-{psf}mm"
        / f"{subject}_desc-pvcMG_psf-{psf}mm_pet.nii.gz"
    )
    if not path.is_file():
        raise SystemExit(f"ERROR: missing PVC image: {path}")

    image = nib.load(str(path))
    if image.shape != pet_img.shape:
        raise SystemExit(f"ERROR: PVC shape mismatch for PSF {psf}")
    if not np.allclose(image.affine, pet_img.affine, atol=1e-4):
        raise SystemExit(f"ERROR: PVC affine mismatch for PSF {psf}")

    data = image.get_fdata(dtype=np.float32)
    valid = (
        reference_atlas
        & (gm >= 0.5)
        & np.isfinite(data)
        & (data > 0)
    )

    if np.count_nonzero(valid) < 20:
        raise SystemExit(
            f"ERROR: too few PVC reference voxels for PSF {psf}"
        )

    reference = float(data[valid].mean())
    if not np.isfinite(reference) or reference <= 0:
        raise SystemExit(
            f"ERROR: invalid PVC reference for PSF {psf}"
        )

    suvr = (data / reference).astype(np.float32)
    suvr_path = (
        results
        / (
            f"{subject}_desc-pvcMG_psf-{psf}mm_"
            "cerebellar-cortex_suvr.nii.gz"
        )
    )
    nib.save(
        nib.Nifti1Image(suvr, image.affine, image.header),
        str(suvr_path),
    )

    pvc_data[psf] = data
    pvc_suvr[psf] = suvr
    pvc_reference[psf] = reference
    pvc_paths[psf] = path
    suvr_paths[psf] = suvr_path

reference_rows = [
    {
        "subject": subject,
        "image": "raw",
        "psf_mm": "",
        "reference_region": "bilateral cerebellar cortex",
        "atlas_labels": "8;47",
        "reference_method": "GM-probability-weighted mean",
        "reference_value": raw_reference,
        "reference_voxels": int(np.count_nonzero(raw_reference_valid)),
        "gm_weight_sum": raw_weight_sum,
    }
]

for psf in (4, 5, 6, 8):
    valid = (
        reference_atlas
        & (gm >= 0.5)
        & np.isfinite(pvc_data[psf])
        & (pvc_data[psf] > 0)
    )
    reference_rows.append(
        {
            "subject": subject,
            "image": "pvcMG",
            "psf_mm": psf,
            "reference_region": "bilateral cerebellar cortex",
            "atlas_labels": "8;47",
            "reference_method": "mean positive PVC in GM>=0.5",
            "reference_value": pvc_reference[psf],
            "reference_voxels": int(np.count_nonzero(valid)),
            "gm_weight_sum": "",
        }
    )

reference_df = pd.DataFrame(reference_rows)
reference_path = results / "reference_values.tsv"
reference_df.to_csv(reference_path, sep="\t", index=False)

voxel_volume = float(abs(np.linalg.det(pet_img.affine[:3, :3])))
roi_rows: list[dict[str, object]] = []

for label in sorted(value for value in np.unique(atlas) if value != 0):
    mask = atlas == label
    count = int(np.count_nonzero(mask))
    if count < 3:
        continue

    raw_valid = mask & np.isfinite(pet) & (pet > 0)
    gm_valid = mask & (gm >= 0.5)

    row: dict[str, object] = {
        "subject": subject,
        "label": int(label),
        "region": labels.get(int(label), f"label-{label}"),
        "voxel_count": count,
        "volume_mm3": count * voxel_volume,
        "is_reference_label": int(label in (8, 47)),
        "raw_pet_mean": (
            float(pet[raw_valid].mean())
            if np.any(raw_valid)
            else np.nan
        ),
        "raw_suvr_mean": (
            float(raw_suvr[raw_valid].mean())
            if np.any(raw_valid)
            else np.nan
        ),
        "gm50_voxel_count": int(np.count_nonzero(gm_valid)),
    }

    for psf in (4, 5, 6, 8):
        valid = (
            gm_valid
            & np.isfinite(pvc_data[psf])
            & (pvc_data[psf] != 0)
        )
        row[f"pvc_psf{psf}_mean"] = (
            float(pvc_data[psf][valid].mean())
            if np.any(valid)
            else np.nan
        )
        row[f"suvr_psf{psf}_mean"] = (
            float(pvc_suvr[psf][valid].mean())
            if np.any(valid)
            else np.nan
        )

    roi_rows.append(row)

roi_df = pd.DataFrame(roi_rows)
roi_path = results / "roi_summary.tsv"
roi_df.to_csv(roi_path, sep="\t", index=False)

sensitivity_rows: list[dict[str, object]] = []

for _, row in roi_df.iterrows():
    values = np.array(
        [
            row["suvr_psf4_mean"],
            row["suvr_psf5_mean"],
            row["suvr_psf6_mean"],
            row["suvr_psf8_mean"],
        ],
        dtype=float,
    )

    finite = np.isfinite(values)
    if np.count_nonzero(finite) < 2:
        continue

    selected = values[finite]
    mean_value = float(selected.mean())
    sd_value = float(selected.std(ddof=0))
    cv_percent = (
        float(sd_value / abs(mean_value) * 100.0)
        if mean_value != 0
        else np.nan
    )

    sensitivity_rows.append(
        {
            "subject": subject,
            "label": int(row["label"]),
            "region": row["region"],
            "is_reference_label": int(row["is_reference_label"]),
            "suvr_psf4": values[0],
            "suvr_psf5": values[1],
            "suvr_psf6": values[2],
            "suvr_psf8": values[3],
            "mean_across_psf": mean_value,
            "sd_across_psf": sd_value,
            "cv_percent": cv_percent,
            "range": float(selected.max() - selected.min()),
            "percent_difference_psf8_vs_psf5": (
                float((values[3] - values[1]) / values[1] * 100.0)
                if np.isfinite(values[3])
                and np.isfinite(values[1])
                and values[1] != 0
                else np.nan
            ),
        }
    )

sensitivity_df = pd.DataFrame(sensitivity_rows)
sensitivity_path = results / "psf_sensitivity.tsv"
sensitivity_df.to_csv(sensitivity_path, sep="\t", index=False)

summary = {
    "subject": subject,
    "tracer": "18F-FDG",
    "static_window": {
        "selection": "FrameTimesStart >= 1800 and < 5400 seconds",
        "selected_frames": 225,
    },
    "suvr_reference": {
        "name": "bilateral cerebellar cortex",
        "desikan_killiany_labels": [8, 47],
        "raw_reference_method": "GM-probability-weighted mean",
        "pvc_reference_method": "mean positive PVC in GM>=0.5",
        "raw_reference_value": raw_reference,
        "pvc_reference_values": {
            str(psf): pvc_reference[psf]
            for psf in (4, 5, 6, 8)
        },
    },
    "pvc": {
        "method": "Muller-Gartner three-compartment",
        "nominal_psf_mm": 5,
        "sensitivity_psf_mm": [4, 6, 8],
        "gm_threshold": 0.5,
        "wm_csf_signal_threshold": 0.9,
    },
    "outputs": {
        "raw_suvr": str(raw_suvr_path),
        "pvc_suvr": {
            str(psf): str(suvr_paths[psf])
            for psf in (4, 5, 6, 8)
        },
        "reference_table": str(reference_path),
        "roi_table": str(roi_path),
        "sensitivity_table": str(sensitivity_path),
    },
}

summary_path = results / "suvr_roi_summary.json"
summary_path.write_text(
    json.dumps(summary, indent=2) + "\n",
    encoding="utf-8",
)

# QC figure: raw SUVR, nominal PVC SUVR and PSF sensitivity difference.
positive = raw_suvr[np.isfinite(raw_suvr) & (raw_suvr > 0)]
threshold = np.percentile(positive, 60)
coords = np.argwhere(np.isfinite(raw_suvr) & (raw_suvr >= threshold))
center = np.round(coords.mean(axis=0)).astype(int)

def get_plane(data: np.ndarray, axis: int, index: int) -> np.ndarray:
    if axis == 0:
        return np.rot90(data[index, :, :])
    if axis == 1:
        return np.rot90(data[:, index, :])
    return np.rot90(data[:, :, index])

fig, axes = plt.subplots(3, 3, figsize=(15, 15))
definitions = [
    ("Sagittal", 0, center[0]),
    ("Coronal", 1, center[1]),
    ("Axial", 2, center[2]),
]

datasets = [
    ("Raw PET SUVR", raw_suvr),
    ("PVC MG SUVR - nominal PSF 5 mm", pvc_suvr[5]),
    ("PVC SUVR difference: PSF 8 minus 4 mm", pvc_suvr[8] - pvc_suvr[4]),
]

for row_index, (row_title, data) in enumerate(datasets):
    finite = data[np.isfinite(data)]
    if "difference" in row_title.lower():
        vmax = float(np.percentile(np.abs(finite), 99))
        vmin = -vmax
    else:
        vmin, vmax = np.percentile(finite, [1, 99])

    for column_index, (plane_title, axis, index) in enumerate(definitions):
        ax = axes[row_index, column_index]
        image = get_plane(data, axis, index)
        ax.imshow(image, origin="lower", vmin=vmin, vmax=vmax)
        ax.set_title(f"{row_title}\n{plane_title}")
        ax.axis("off")

plt.tight_layout()
suvr_qc_path = results / "qc_suvr_psf_contact_sheet.png"
fig.savefig(suvr_qc_path, dpi=180, bbox_inches="tight")
plt.close(fig)

# ROI raw-vs-PVC scatter.
plot_df = roi_df[
    np.isfinite(roi_df["raw_suvr_mean"])
    & np.isfinite(roi_df["suvr_psf5_mean"])
    & (roi_df["is_reference_label"] == 0)
].copy()

fig = plt.figure(figsize=(8, 8))
plt.scatter(
    plot_df["raw_suvr_mean"],
    plot_df["suvr_psf5_mean"],
    s=18,
)
low = float(
    min(
        plot_df["raw_suvr_mean"].min(),
        plot_df["suvr_psf5_mean"].min(),
    )
)
high = float(
    max(
        plot_df["raw_suvr_mean"].max(),
        plot_df["suvr_psf5_mean"].max(),
    )
)
plt.plot([low, high], [low, high], linestyle="--")
plt.xlabel("Raw PET SUVR ROI mean")
plt.ylabel("PVC MG PSF 5 mm SUVR ROI mean")
plt.title("ROI comparison: raw versus nominal PVC")
plt.tight_layout()
scatter_path = results / "qc_roi_raw_vs_pvc5.png"
fig.savefig(scatter_path, dpi=180)
plt.close(fig)

# PSF sensitivity plot for the regions with the largest range.
plot_sensitivity = sensitivity_df[
    np.isfinite(sensitivity_df["range"])
    & (sensitivity_df["is_reference_label"] == 0)
].sort_values("range", ascending=False).head(15)

fig = plt.figure(figsize=(12, 8))
x = np.array([4, 5, 6, 8], dtype=float)

for _, row in plot_sensitivity.iterrows():
    y = np.array(
        [
            row["suvr_psf4"],
            row["suvr_psf5"],
            row["suvr_psf6"],
            row["suvr_psf8"],
        ],
        dtype=float,
    )
    plt.plot(x, y, marker="o", label=str(row["region"]))

plt.xlabel("Assumed isotropic PSF FWHM (mm)")
plt.ylabel("ROI mean PVC SUVR")
plt.title("Regions with largest PVC PSF sensitivity")
plt.xticks(x)
plt.legend(fontsize=7, loc="best")
plt.tight_layout()
sensitivity_plot_path = results / "qc_roi_psf_sensitivity.png"
fig.savefig(sensitivity_plot_path, dpi=180)
plt.close(fig)

print(json.dumps(summary, indent=2))
print(f"QC: {suvr_qc_path}")
print(f"QC: {scatter_path}")
print(f"QC: {sensitivity_plot_path}")
