from __future__ import annotations

import json
from pathlib import Path

import nibabel as nib
import numpy as np

subject = "sub-01"
root = Path(
    "/media/andraderenew/Elements/neuroimaging/"
    "pet_fdg-suvr-pvc_spm-petpve12_openneuro-ds002898/"
    "work/sub-01/petpve12"
)

summaries: list[dict[str, object]] = []

for psf in (4, 5, 6, 8):
    run_dir = root / f"psf-{psf}mm"
    source_path = run_dir / f"pvc{subject}_pet.nii"
    reference_path = run_dir / f"{subject}_pet.nii"
    output_path = (
        run_dir
        / f"{subject}_desc-pvcMG_psf-{psf}mm_pet.nii.gz"
    )

    if not source_path.is_file():
        raise SystemExit(f"ERROR: missing PETPVE12 output: {source_path}")

    source_img = nib.load(str(source_path))
    reference_img = nib.load(str(reference_path))

    if source_img.shape != reference_img.shape:
        raise SystemExit(
            f"ERROR: shape mismatch for PSF {psf}: "
            f"{source_img.shape} vs {reference_img.shape}"
        )
    if not np.allclose(source_img.affine, reference_img.affine, atol=1e-4):
        raise SystemExit(f"ERROR: affine mismatch for PSF {psf}")

    data = source_img.get_fdata(dtype=np.float32)
    finite = np.isfinite(data)
    nonfinite_count = int(data.size - np.count_nonzero(finite))

    clean = np.where(finite, data, 0.0).astype(np.float32)
    nib.save(
        nib.Nifti1Image(clean, source_img.affine, source_img.header),
        str(output_path),
    )

    nonzero = clean != 0
    positive = clean > 0
    negative = clean < 0

    summary = {
        "subject": subject,
        "method": "Muller-Gartner three-compartment",
        "psf_fwhm_mm": [psf, psf, psf],
        "gm_threshold": 0.5,
        "wm_csf_signal_threshold": 0.9,
        "source_output": str(source_path),
        "standardized_output": str(output_path),
        "shape": list(source_img.shape),
        "voxel_sizes_mm": [
            float(value)
            for value in source_img.header.get_zooms()[:3]
        ],
        "nonfinite_voxel_count_replaced_with_zero": nonfinite_count,
        "nonzero_voxel_count": int(np.count_nonzero(nonzero)),
        "positive_voxel_count": int(np.count_nonzero(positive)),
        "negative_voxel_count": int(np.count_nonzero(negative)),
        "minimum_finite": float(clean.min()),
        "maximum_finite": float(clean.max()),
        "mean_positive": (
            float(clean[positive].mean())
            if np.any(positive)
            else None
        ),
    }

    summary_path = run_dir / "petpve12_summary.json"
    summary_path.write_text(
        json.dumps(summary, indent=2) + "\n",
        encoding="utf-8",
    )
    summaries.append(summary)

(root / "petpve12_sensitivity_summary.json").write_text(
    json.dumps(summaries, indent=2) + "\n",
    encoding="utf-8",
)

print(json.dumps(summaries, indent=2))
