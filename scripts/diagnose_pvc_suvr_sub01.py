from __future__ import annotations

import json
import math
from pathlib import Path

import matplotlib.pyplot as plt
import nibabel as nib
import numpy as np
import pandas as pd
from PIL import Image, ImageOps, ImageDraw

subject = "sub-01"
project_root = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898"
)
work = project_root / "work" / subject
results = work / "results"
spm_work = work / "spm"
atlas_work = work / "atlas"

raw_path = results / f"{subject}_desc-raw_cerebellar-cortex_suvr.nii.gz"
pvc_paths = {
    psf: (
        results
        / f"{subject}_desc-pvcMG_psf-{psf}mm_cerebellar-cortex_suvr.nii.gz"
    )
    for psf in (4, 5, 6, 8)
}
gm_path = spm_work / f"rc1{subject}_T1w.nii"
atlas_path = (
    atlas_work
    / f"{subject}_space-pet_desc-desikan-killiany_atlas.nii.gz"
)
roi_path = results / "roi_summary.tsv"
sensitivity_path = results / "psf_sensitivity.tsv"

required = [
    raw_path,
    gm_path,
    atlas_path,
    roi_path,
    sensitivity_path,
    *pvc_paths.values(),
]
for path in required:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"ERROR: falta el archivo {path}")

raw_img = nib.load(str(raw_path))
gm_img = nib.load(str(gm_path))
atlas_img = nib.load(str(atlas_path))
pvc_imgs = {psf: nib.load(str(path)) for psf, path in pvc_paths.items()}

for image in [gm_img, atlas_img, *pvc_imgs.values()]:
    if image.shape != raw_img.shape:
        raise SystemExit(
            f"ERROR: shape distinta: {image.shape} frente a {raw_img.shape}"
        )
    if not np.allclose(image.affine, raw_img.affine, atol=1e-4):
        raise SystemExit("ERROR: affine distinta en los mapas SUVR")

raw = raw_img.get_fdata(dtype=np.float32)
gm = np.clip(gm_img.get_fdata(dtype=np.float32), 0.0, 1.0)
atlas = np.rint(atlas_img.get_fdata(dtype=np.float32)).astype(np.int32)
pvc = {
    psf: image.get_fdata(dtype=np.float32)
    for psf, image in pvc_imgs.items()
}

analysis_mask = (atlas > 0) & (gm >= 0.5)
if np.count_nonzero(analysis_mask) < 1000:
    raise SystemExit("ERROR: la máscara GM del atlas es demasiado pequeña")

def describe(name: str, data: np.ndarray) -> dict[str, object]:
    valid = analysis_mask & np.isfinite(data)
    values = data[valid]

    if values.size == 0:
        raise SystemExit(f"ERROR: sin valores válidos para {name}")

    percentiles = np.percentile(
        values,
        [0, 0.1, 1, 5, 25, 50, 75, 95, 99, 99.9, 100],
    )

    return {
        "image": name,
        "voxel_count": int(values.size),
        "negative_voxels": int(np.count_nonzero(values < 0)),
        "zero_voxels": int(np.count_nonzero(values == 0)),
        "positive_voxels": int(np.count_nonzero(values > 0)),
        "negative_percent": float(np.mean(values < 0) * 100.0),
        "zero_percent": float(np.mean(values == 0) * 100.0),
        "above_3_percent": float(np.mean(values > 3.0) * 100.0),
        "above_5_percent": float(np.mean(values > 5.0) * 100.0),
        "mean": float(np.mean(values)),
        "median": float(np.median(values)),
        "standard_deviation": float(np.std(values)),
        "percentiles": {
            key: float(value)
            for key, value in zip(
                ["0", "0.1", "1", "5", "25", "50", "75", "95", "99", "99.9", "100"],
                percentiles,
            )
        },
    }

image_summaries = [describe("raw", raw)]
image_summaries.extend(
    describe(f"pvc_psf_{psf}mm", pvc[psf])
    for psf in (4, 5, 6, 8)
)

roi = pd.read_csv(roi_path, sep="\t")
sensitivity = pd.read_csv(sensitivity_path, sep="\t")

cortical_labels = set(range(1001, 1036)) | set(range(2001, 2036))
cortical_labels -= {1004, 2004}

subcortical_labels = {
    10, 11, 12, 13, 17, 18, 26, 28,
    49, 50, 51, 52, 53, 54, 58, 60,
}
primary_labels = cortical_labels | subcortical_labels

roi["primary_gray_roi"] = roi["label"].isin(primary_labels).astype(int)
primary_roi = roi[roi["primary_gray_roi"] == 1].copy()

primary_roi["flag_low_gm_support"] = (
    primary_roi["gm50_voxel_count"] < 20
).astype(int)
primary_roi["flag_negative_nominal_mean"] = (
    primary_roi["suvr_psf5_mean"] < 0
).astype(int)
primary_roi["flag_nonfinite_nominal_mean"] = (
    ~np.isfinite(primary_roi["suvr_psf5_mean"])
).astype(int)

primary_sensitivity = sensitivity[
    sensitivity["label"].isin(primary_labels)
].copy()
primary_sensitivity["flag_cv_above_10pct"] = (
    primary_sensitivity["cv_percent"] > 10.0
).astype(int)
primary_sensitivity["flag_cv_above_20pct"] = (
    primary_sensitivity["cv_percent"] > 20.0
).astype(int)

primary_roi_path = results / "diagnostic_primary_gray_roi.tsv"
primary_sensitivity_path = (
    results / "diagnostic_primary_gray_psf_sensitivity.tsv"
)
primary_roi.to_csv(primary_roi_path, sep="\t", index=False)
primary_sensitivity.to_csv(
    primary_sensitivity_path,
    sep="\t",
    index=False,
)

all_negative = roi[
    np.isfinite(roi["suvr_psf5_mean"])
    & (roi["suvr_psf5_mean"] < 0)
].copy()

top_sensitivity = primary_sensitivity[
    np.isfinite(primary_sensitivity["cv_percent"])
].sort_values("cv_percent", ascending=False).head(20)

diagnostic = {
    "subject": subject,
    "analysis_mask": "Desikan-Killiany labels > 0 and GM probability >= 0.5",
    "analysis_mask_voxels": int(np.count_nonzero(analysis_mask)),
    "image_summaries": image_summaries,
    "primary_gray_roi_definition": {
        "cortical_labels": "1001-1035 and 2001-2035, excluding 1004 and 2004",
        "subcortical_labels": sorted(subcortical_labels),
    },
    "primary_gray_roi_count": int(len(primary_roi)),
    "primary_low_gm_support_count": int(
        primary_roi["flag_low_gm_support"].sum()
    ),
    "primary_negative_nominal_mean_count": int(
        primary_roi["flag_negative_nominal_mean"].sum()
    ),
    "primary_nonfinite_nominal_mean_count": int(
        primary_roi["flag_nonfinite_nominal_mean"].sum()
    ),
    "all_atlas_negative_nominal_roi_count": int(len(all_negative)),
    "all_atlas_negative_nominal_rois": (
        all_negative[
            ["label", "region", "gm50_voxel_count", "suvr_psf5_mean"]
        ]
        .to_dict(orient="records")
    ),
    "primary_psf_cv_above_10pct_count": int(
        primary_sensitivity["flag_cv_above_10pct"].sum()
    ),
    "primary_psf_cv_above_20pct_count": int(
        primary_sensitivity["flag_cv_above_20pct"].sum()
    ),
    "top_primary_psf_sensitivity": (
        top_sensitivity[
            [
                "label",
                "region",
                "suvr_psf4",
                "suvr_psf5",
                "suvr_psf6",
                "suvr_psf8",
                "cv_percent",
                "range",
            ]
        ]
        .to_dict(orient="records")
    ),
    "diagnostic_tables": {
        "primary_gray_roi": str(primary_roi_path),
        "primary_gray_psf_sensitivity": str(primary_sensitivity_path),
    },
}

json_path = results / "pvc_suvr_diagnostic.json"
json_path.write_text(
    json.dumps(diagnostic, indent=2) + "\n",
    encoding="utf-8",
)

text_lines = [
    "OpenNeuro ds002898 sub-01 PVC/SUVR diagnostic",
    "",
    f"Analysis-mask voxels: {diagnostic['analysis_mask_voxels']}",
    "",
    "Image distributions within atlas GM>=0.5:",
]

for summary in image_summaries:
    p = summary["percentiles"]
    text_lines.extend(
        [
            (
                f"  {summary['image']}: median={summary['median']:.4f}, "
                f"p1={p['1']:.4f}, p99={p['99']:.4f}, "
                f"min={p['0']:.4f}, max={p['100']:.4f}"
            ),
            (
                f"    negative={summary['negative_percent']:.4f}%, "
                f"zero={summary['zero_percent']:.4f}%, "
                f">3={summary['above_3_percent']:.4f}%, "
                f">5={summary['above_5_percent']:.4f}%"
            ),
        ]
    )

text_lines.extend(
    [
        "",
        f"Primary gray ROIs: {len(primary_roi)}",
        (
            "Primary ROIs with GM50 support <20 voxels: "
            f"{diagnostic['primary_low_gm_support_count']}"
        ),
        (
            "Primary ROIs with negative nominal PVC mean: "
            f"{diagnostic['primary_negative_nominal_mean_count']}"
        ),
        (
            "Primary ROIs with non-finite nominal PVC mean: "
            f"{diagnostic['primary_nonfinite_nominal_mean_count']}"
        ),
        (
            "All atlas labels with negative nominal PVC mean: "
            f"{diagnostic['all_atlas_negative_nominal_roi_count']}"
        ),
        (
            "Primary ROIs with PSF CV >10%: "
            f"{diagnostic['primary_psf_cv_above_10pct_count']}"
        ),
        (
            "Primary ROIs with PSF CV >20%: "
            f"{diagnostic['primary_psf_cv_above_20pct_count']}"
        ),
        "",
        "Top primary gray ROIs by PSF CV:",
    ]
)

for row in diagnostic["top_primary_psf_sensitivity"][:15]:
    text_lines.append(
        f"  {row['region']}: CV={row['cv_percent']:.3f}%, "
        f"range={row['range']:.4f}, "
        f"PSF5={row['suvr_psf5']:.4f}"
    )

text_path = results / "pvc_suvr_diagnostic.txt"
text_path.write_text(
    "\n".join(text_lines) + "\n",
    encoding="utf-8",
)

positive_raw = raw[analysis_mask & np.isfinite(raw) & (raw > 0)]
threshold = np.percentile(positive_raw, 60)
coords = np.argwhere(
    analysis_mask & np.isfinite(raw) & (raw >= threshold)
)
center = np.round(coords.mean(axis=0)).astype(int)

def plane(data: np.ndarray, axis: int, index: int) -> np.ndarray:
    if axis == 0:
        return np.rot90(data[index, :, :])
    if axis == 1:
        return np.rot90(data[:, index, :])
    return np.rot90(data[:, :, index])

def make_planes(
    data: np.ndarray,
    title: str,
    output: Path,
    symmetric: bool = False,
) -> None:
    values = data[analysis_mask & np.isfinite(data)]
    if symmetric:
        bound = float(np.percentile(np.abs(values), 99))
        vmin, vmax = -bound, bound
    else:
        vmin, vmax = np.percentile(values, [1, 99])

    for axis, axis_name in enumerate(("sagittal", "coronal", "axial")):
        fig = plt.figure(figsize=(6, 6))
        plt.imshow(
            plane(data, axis, int(center[axis])),
            origin="lower",
            vmin=vmin,
            vmax=vmax,
        )
        plt.title(f"{title} - {axis_name}")
        plt.axis("off")
        plt.tight_layout()
        fig.savefig(
            output.with_name(
                f"{output.stem}_{axis_name}{output.suffix}"
            ),
            dpi=180,
            bbox_inches="tight",
        )
        plt.close(fig)

raw_prefix = results / "diagnostic_raw_suvr.png"
pvc5_prefix = results / "diagnostic_pvc5_suvr.png"
diff_prefix = results / "diagnostic_psf8_minus4.png"

make_planes(raw, "Raw SUVR robust 1-99% window", raw_prefix)
make_planes(
    pvc[5],
    "PVC MG PSF 5 mm SUVR robust 1-99% window",
    pvc5_prefix,
)
make_planes(
    pvc[8] - pvc[4],
    "PVC SUVR difference PSF 8 minus 4 mm",
    diff_prefix,
    symmetric=True,
)

fig = plt.figure(figsize=(8, 6))
for name, data in (
    ("raw", raw),
    ("PVC 4 mm", pvc[4]),
    ("PVC 5 mm", pvc[5]),
    ("PVC 6 mm", pvc[6]),
    ("PVC 8 mm", pvc[8]),
):
    values = data[analysis_mask & np.isfinite(data)]
    low, high = np.percentile(values, [0.5, 99.5])
    clipped = values[(values >= low) & (values <= high)]
    plt.hist(clipped, bins=120, histtype="step", density=True, label=name)

plt.xlabel("SUVR")
plt.ylabel("Density")
plt.title("SUVR distributions in atlas GM>=0.5")
plt.legend()
plt.tight_layout()
hist_path = results / "diagnostic_suvr_histograms.png"
fig.savefig(hist_path, dpi=180)
plt.close(fig)

fig = plt.figure(figsize=(9, 7))
valid_primary = primary_roi[
    np.isfinite(primary_roi["raw_suvr_mean"])
    & np.isfinite(primary_roi["suvr_psf5_mean"])
]
plt.scatter(
    valid_primary["raw_suvr_mean"],
    valid_primary["suvr_psf5_mean"],
)
low = float(
    min(
        valid_primary["raw_suvr_mean"].min(),
        valid_primary["suvr_psf5_mean"].min(),
    )
)
high = float(
    max(
        valid_primary["raw_suvr_mean"].max(),
        valid_primary["suvr_psf5_mean"].max(),
    )
)
plt.plot([low, high], [low, high], linestyle="--")
plt.xlabel("Raw SUVR mean")
plt.ylabel("PVC MG PSF 5 mm SUVR mean")
plt.title("Primary gray-matter ROI comparison")
plt.tight_layout()
scatter_path = results / "diagnostic_primary_gray_raw_vs_pvc5.png"
fig.savefig(scatter_path, dpi=180)
plt.close(fig)

image_paths = [
    results / "diagnostic_raw_suvr_sagittal.png",
    results / "diagnostic_raw_suvr_coronal.png",
    results / "diagnostic_raw_suvr_axial.png",
    results / "diagnostic_pvc5_suvr_sagittal.png",
    results / "diagnostic_pvc5_suvr_coronal.png",
    results / "diagnostic_pvc5_suvr_axial.png",
    results / "diagnostic_psf8_minus4_sagittal.png",
    results / "diagnostic_psf8_minus4_coronal.png",
    results / "diagnostic_psf8_minus4_axial.png",
    hist_path,
    scatter_path,
]

opened = [Image.open(path).convert("RGB") for path in image_paths]
thumb_width = 700
thumbs = []

for image in opened:
    ratio = thumb_width / image.width
    resized = image.resize(
        (thumb_width, max(1, int(image.height * ratio)))
    )
    thumbs.append(resized)

rows = [
    thumbs[0:3],
    thumbs[3:6],
    thumbs[6:9],
    thumbs[9:11],
]

padding = 20
row_heights = [max(image.height for image in row) for row in rows]
canvas_width = 3 * thumb_width + 4 * padding
canvas_height = sum(row_heights) + (len(rows) + 1) * padding + 100

canvas = Image.new("RGB", (canvas_width, canvas_height), "white")
draw = ImageDraw.Draw(canvas)
draw.text(
    (padding, 20),
    "OpenNeuro ds002898 sub-01 - PVC/SUVR robust diagnostic",
    fill="black",
)

y = 100
for row, row_height in zip(rows, row_heights):
    x = padding
    for image in row:
        canvas.paste(image, (x, y))
        x += thumb_width + padding
    y += row_height + padding

contact_path = results / "qc_pvc_suvr_robust_diagnostic.png"
canvas.save(contact_path)

download_contact = (
    Path.home() / "Downloads" / "qc_pvc_suvr_robust_diagnostic.png"
)
download_text = (
    Path.home() / "Downloads" / "pvc_suvr_diagnostic.txt"
)
download_json = (
    Path.home() / "Downloads" / "pvc_suvr_diagnostic.json"
)

Image.open(contact_path).save(download_contact)
download_text.write_text(text_path.read_text(encoding="utf-8"), encoding="utf-8")
download_json.write_text(json_path.read_text(encoding="utf-8"), encoding="utf-8")

print("\n".join(text_lines))
print()
print("Diagnostic image:")
print(f"  {download_contact}")
print("Diagnostic text:")
print(f"  {download_text}")
print("Diagnostic JSON:")
print(f"  {download_json}")
